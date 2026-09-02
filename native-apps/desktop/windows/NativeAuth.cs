using System;
using System.Globalization;
using System.Net;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace GeregeNexusNativeWin;

public enum LoginPhase { Idle, Starting, Waiting, Success, Expired, Refused, Error }
public sealed record LoginStatus(LoginPhase Phase, string Message = "");

/// <summary>
/// Нэвтэрсэн хэрэглэгч — ribbon-ы профайл цэсэнд харагдана (macOS-ийн
/// NativeUserProfile). Нууц үгээр нэвтрэхэд backend бүтэн мэдээллийг өгдөг;
/// eID урсгал зөвхөн session өгдөг тул тэнд ерөнхий нэр үлдэнэ.
/// </summary>
public sealed record NativeUserProfile(string Id, string Name, string Email, string TenantId)
{
    public static readonly NativeUserProfile EidUser = new("", "eID хэрэглэгч", "", "");
}

internal sealed record PasswordLoginResponse(
    [property: JsonPropertyName("user")] PasswordLoginUser? User);

/// <summary>
/// `GET auth/me`-ийн хариу. Backend нь хэрэглэгчийг дугтуйлж (<c>{"user":…}</c>)
/// эсвэл шууд буцааж болох тул хоёуланг нь тэсвэрлэнэ.
/// </summary>
internal sealed record MeResponse(
    [property: JsonPropertyName("user")] PasswordLoginUser? User,
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("name")] string? Name,
    [property: JsonPropertyName("email")] string? Email,
    [property: JsonPropertyName("tenant_id")] string? TenantId)
{
    public PasswordLoginUser? Resolve() =>
        User ?? (string.IsNullOrWhiteSpace(Name) && string.IsNullOrWhiteSpace(Email)
            ? null
            : new PasswordLoginUser(Id, Name, Email, TenantId));
}

internal sealed record PasswordLoginUser(
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("name")] string? Name,
    [property: JsonPropertyName("email")] string? Email,
    [property: JsonPropertyName("tenant_id")] string? TenantId);
internal sealed record EIDStart(
    [property: JsonPropertyName("session_id")] string SessionId,
    [property: JsonPropertyName("verification_code")] string VerificationCode,
    [property: JsonPropertyName("expires_at")]
    [property: JsonConverter(typeof(LenientTimestampConverter))] DateTimeOffset? ExpiresAt,
    [property: JsonPropertyName("device_link_url")] string? DeviceLinkUrl);

/// <summary>
/// Тогтоогүй хугацааг backend нь `null` биш ХООСОН МӨРӨӨР (<c>"expires_at": ""</c>)
/// буцаадаг. System.Text.Json хоосон мөрийг DateTimeOffset болгож чаддаггүй тул
/// нэвтрэлт эхлэх бүрд "The JSON value could not be converted" гэж унана —
/// нэвтрэх боломжгүй болно. Энэ хөрвүүлэгч хоосныг null болгож, PollAsync-ийн
/// 15 минутын анхдагч хугацаанд шилжүүлнэ. Epoch тоогоор ирэхийг ч тэсвэрлэнэ.
/// </summary>
internal sealed class LenientTimestampConverter : JsonConverter<DateTimeOffset?>
{
    public override DateTimeOffset? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        switch (reader.TokenType)
        {
            case JsonTokenType.Null:
                return null;
            case JsonTokenType.String:
                var raw = reader.GetString();
                if (string.IsNullOrWhiteSpace(raw)) return null;
                return DateTimeOffset.TryParse(
                    raw, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var parsed)
                    ? parsed
                    : null;
            case JsonTokenType.Number when reader.TryGetInt64(out var epoch):
                // Секунд ба миллисекундийг хэмжээгээр нь ялгана.
                return epoch > 100_000_000_000L
                    ? DateTimeOffset.FromUnixTimeMilliseconds(epoch)
                    : DateTimeOffset.FromUnixTimeSeconds(epoch);
            default:
                return null;
        }
    }

    public override void Write(Utf8JsonWriter writer, DateTimeOffset? value, JsonSerializerOptions options)
    {
        ArgumentNullException.ThrowIfNull(writer);
        if (value is null) writer.WriteNullValue();
        else writer.WriteStringValue(value.Value);
    }
}
internal sealed record EIDPoll([property: JsonPropertyName("state")] string State);

public sealed class NativeAuth : IDisposable
{
    private readonly Uri _apiBase;
    private readonly CookieContainer _cookies = new();
    private readonly HttpClient _http;
    private CancellationTokenSource? _attempt;
    private long _ticket;
    public event Action<LoginStatus>? StatusChanged;
    public string? LastDeviceLinkUrl { get; private set; }

    /// <summary>Нэвтэрсэн хэрэглэгч. Нэвтрээгүй үед null.</summary>
    public NativeUserProfile? Profile { get; private set; }

    public NativeAuth(string apiEndpoint)
    {
        var root = apiEndpoint.TrimEnd('/'); if (!root.EndsWith("/api/v1", StringComparison.OrdinalIgnoreCase)) root += "/api/v1";
        _apiBase = new Uri(root + "/");
        _http = new HttpClient(new HttpClientHandler { CookieContainer = _cookies, UseCookies = true }) { BaseAddress = _apiBase };
        _http.DefaultRequestHeaders.AcceptLanguage.ParseAdd("mn");
        _http.DefaultRequestHeaders.Add("Origin", _apiBase.GetLeftPart(UriPartial.Authority));
    }

    /// <summary>
    /// Нэвтрэлтийн хүсэлтийг ажлын мужийн webview-тэй ИЖИЛ User-Agent-аар
    /// явуулна.
    ///
    /// Бүрхүүл нэвтэрч session_token авдаг ч түүнийг webview рүү хуулахад
    /// сервер хүлээж авахгүй байх боломжтой: session нь үүсгэсэн клиентийн
    /// хүрээнд (UA) баригдвал өөр UA-тай webview-ээс ирэхэд хүчингүй болно.
    /// Хоёр талыг нэг UA дээр тавьснаар тэр ялгаа арилна. WebView2 бэлэн
    /// болмогц MainWindow энэ утгыг дамжуулна.
    /// </summary>
    public void UseUserAgent(string userAgent)
    {
        if (string.IsNullOrWhiteSpace(userAgent)) return;
        _http.DefaultRequestHeaders.Remove("User-Agent");
        _http.DefaultRequestHeaders.TryAddWithoutValidation("User-Agent", userAgent);
        ShellLog.Write($"auth: User-Agent тэгшитгэв — {userAgent}");
    }

    /// <summary>
    /// Нэвтрэлтийн бүх cookie. <c>GetCookies(_apiBase)</c> нь зөвхөн
    /// <c>/api/v1/</c> зам дор багтах cookie-г буцаадаг тул сервер өөр замд
    /// (эсвэл өөр дэд домэйнд) тавьсан session нь ажлын мужид хуулагдалгүй
    /// үлдэж, бүрхүүл нэвтэрсэн атлаа вэб хуудас нэвтрээгүй харагддаг байв.
    /// Container-ын бүх cookie-г өгч, шүүлтийг дуудагчид үлдээнэ.
    /// </summary>
    public CookieCollection SessionCookies => _cookies.GetAllCookies();

    public void Cancel()
    {
        Interlocked.Increment(ref _ticket);
        _attempt?.Cancel(); _attempt?.Dispose(); _attempt = null;
        Publish(LoginPhase.Idle);
    }

    public Task PasswordAsync(string email, string password) => BeginAsync(async (ticket, token) =>
    {
        var response = await PostAsync<PasswordLoginResponse>("auth/login", new { email, password }, token);
        if (ticket != _ticket) return;
        if (response.User is { } user)
        {
            Profile = new NativeUserProfile(
                user.Id ?? string.Empty, user.Name ?? string.Empty,
                user.Email ?? string.Empty, user.TenantId ?? string.Empty);
        }
        Publish(LoginPhase.Success);
    });

    /// <summary>
    /// Нэвтэрсэн хэрэглэгчийн мэдээллийг татна. Best-effort: энэ маршрут
    /// байхгүй эсвэл алдаа өгвөл дуудагч ерөнхий нэр рүү унана.
    /// </summary>
    private async Task LoadProfileAsync(CancellationToken token)
    {
        try
        {
            using var response = await _http.GetAsync("auth/me", token).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode) return;
            var dto = await response.Content.ReadFromJsonAsync<MeResponse>(cancellationToken: token).ConfigureAwait(false);
            if (dto?.Resolve() is not { } user) return;
            Profile = new NativeUserProfile(
                user.Id ?? string.Empty, user.Name ?? string.Empty,
                user.Email ?? string.Empty, user.TenantId ?? string.Empty);
        }
        catch (Exception error) when (error is HttpRequestException or JsonException or NotSupportedException)
        {
            // Профайл нь чимэглэл — нэвтрэлтийг үүний төлөө унагаахгүй.
        }
    }

    /// <summary>
    /// Session-ийг серверт хаана. macOS-ийн logout-тай ижил: хариу нь чухал
    /// биш — сервер аль хэдийн мартсан байж болно — тул алдааг залгина.
    /// Клиент талын cookie-г дуудагч цэвэрлэнэ.
    /// </summary>
    public async Task LogoutAsync(CancellationToken token = default)
    {
        Cancel();
        Profile = null;
        try { using var response = await _http.PostAsync("auth/logout", content: null, token); }
        catch (HttpRequestException) { }
        catch (OperationCanceledException) { }
    }

    public Task StaffPinAsync(string pin, string deviceToken) => BeginAsync(async (ticket, token) =>
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "devices/staff/pin") { Content = JsonContent.Create(new { pin }) };
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Device", deviceToken);
        using var response = await _http.SendAsync(request, token);
        if (!response.IsSuccessStatusCode) throw new HttpRequestException($"PIN нэвтрэлт амжилтгүй: HTTP {(int)response.StatusCode}");
        if (ticket == _ticket) Publish(LoginPhase.Success);
    });

    public Task PushAsync(string nationalId) => BeginAsync(async (ticket, token) =>
    {
        var started = await PostAsync<EIDStart>("auth/eid/start-id", new {
            national_id = nationalId.Trim().ToUpperInvariant(), callbackUrl = ""
        }, token);
        if (ticket != _ticket) return;
        Publish(LoginPhase.Waiting, $"eID апп дээр зөвшөөрнө үү. Код: {started.VerificationCode}");
        await PollAsync(started, ticket, token);
    });

    public Task QrAsync() => BeginAsync(async (ticket, token) =>
    {
        var started = await PostAsync<EIDStart>("auth/eid/start", new { callbackUrl = "" }, token);
        LastDeviceLinkUrl = started.DeviceLinkUrl;
        if (ticket != _ticket) return;
        Publish(LoginPhase.Waiting, $"eID апп-аар QR уншуулна уу. Код: {started.VerificationCode}");
        await PollAsync(started, ticket, token);
    });

    private async Task BeginAsync(Func<long, CancellationToken, Task> operation)
    {
        Cancel();
        var ticket = Interlocked.Increment(ref _ticket);
        _attempt = new CancellationTokenSource();
        Publish(LoginPhase.Starting, "Хүсэлт эхлүүлж байна…");
        try { await operation(ticket, _attempt.Token); }
        catch (OperationCanceledException) { }
        catch (Exception error) when (ticket == _ticket) { Publish(LoginPhase.Error, error.Message); }
    }

    private async Task PollAsync(EIDStart start, long ticket, CancellationToken token)
    {
        var deadline = start.ExpiresAt ?? DateTimeOffset.UtcNow.AddMinutes(15);
        var failures = 0;
        while (ticket == _ticket && !token.IsCancellationRequested)
        {
            if (DateTimeOffset.UtcNow >= deadline) { Publish(LoginPhase.Expired, "Хугацаа дууслаа"); return; }
            try
            {
                var result = await PostAsync<EIDPoll>("auth/eid/poll", new { session_id = start.SessionId }, token);
                failures = 0;
                switch (result.State.ToUpperInvariant())
                {
                    // eID-ийн poll нь профайл буцаадаггүй. Session cookie аль
                    // хэдийн гарт орсон тул хэрэглэгчийн нэрийг auth/me-ээс
                    // авна — эс бөгөөс ribbon дээр "eID хэрэглэгч" гэсэн
                    // ерөнхий нэр үлдэж, ажлын муж бодит нэрийг харуулж байхад
                    // бүрхүүл нь мэдэхгүй мэт харагдана.
                    case "COMPLETE":
                        await LoadProfileAsync(token).ConfigureAwait(false);
                        Profile ??= NativeUserProfile.EidUser;
                        Publish(LoginPhase.Success);
                        return;
                    case "EXPIRED": Publish(LoginPhase.Expired, "Хугацаа дууслаа"); return;
                    case "REFUSED": Publish(LoginPhase.Refused, "Хүсэлтээс татгалзлаа"); return;
                }
            }
            catch (OperationCanceledException) { throw; }
            catch when (++failures <= 3) { }
            await Task.Delay(400, token);
        }
    }

    private async Task PostAsync(string path, object body, CancellationToken token) =>
        _ = await PostAsync<object>(path, body, token);

    private async Task<T> PostAsync<T>(string path, object body, CancellationToken token)
    {
        using var response = await _http.PostAsJsonAsync(path, body, token);
        if (response.Headers.TryGetValues("Set-Cookie", out var issued))
        {
            // Нууц утгыг бичихгүй — зөвхөн нэр ба шинжүүд.
            foreach (var raw in issued)
            {
                var name = raw.Split('=')[0];
                var attributes = raw.Contains(';') ? raw[raw.IndexOf(';')..] : string.Empty;
                ShellLog.Write($"auth: {path} Set-Cookie {name}{attributes}");
            }
        }
        if (!response.IsSuccessStatusCode)
        {
            var error = await response.Content.ReadFromJsonAsync<ApiError>(cancellationToken: token);
            throw new HttpRequestException(error?.Error ?? $"HTTP {(int)response.StatusCode}");
        }
        return (await response.Content.ReadFromJsonAsync<T>(cancellationToken: token))!;
    }

    private void Publish(LoginPhase phase, string message = "") => StatusChanged?.Invoke(new LoginStatus(phase, message));
    public void Dispose() { Cancel(); _http.Dispose(); }
    private sealed record ApiError([property: JsonPropertyName("error")] string Error);
}

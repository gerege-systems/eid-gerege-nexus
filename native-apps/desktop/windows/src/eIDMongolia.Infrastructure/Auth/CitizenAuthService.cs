using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using eIDMongolia.Application.Abstractions;
using eIDMongolia.Domain.Auth;
using eIDMongolia.Domain.Primitives;
using Microsoft.Extensions.Logging;

namespace eIDMongolia.Infrastructure.Auth;

/// Citizen-facing auth flow — **first-party** model (see BACKEND-INTEGRATION.md).
///
/// Talks to the e-ID Mongolia WEB backend's public `/api/*` routes exactly like
/// a browser (no RP secret, no device HMAC, no bearer):
///   • national-id push  → POST /api/login-notify {register}
///   • QR                → POST /api/start
///   • poll              → GET  /api/status?sessionId=&pollToken=
///
/// `/api/status` returns `name` + `idNumber` inline on completion (no bearer /
/// no `/me`), so on success we stash that identity in
/// <see cref="ISessionIdentityCache"/> for `UserProfileService.GetMeAsync`.
public sealed class CitizenAuthService : ICitizenAuthService
{
    /// The web session default TTL isn't echoed by `/api/*`; use a conservative
    /// client-side estimate purely to drive the "code expired" UI countdown.
    private static readonly TimeSpan SessionTtl = TimeSpan.FromMinutes(5);

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private readonly HttpClient _http;
    private readonly IWebSessionStore _sessions;
    private readonly ISessionIdentityCache _identity;
    private readonly ILogger<CitizenAuthService> _logger;

    public CitizenAuthService(
        HttpClient http,
        IWebSessionStore sessions,
        ISessionIdentityCache identity,
        ILogger<CitizenAuthService> logger)
    {
        _http = http;
        _sessions = sessions;
        _identity = identity;
        _logger = logger;
    }

    public async Task<Result<WebAuthSession>> InitiateAsync(string nationalId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(nationalId))
        {
            return Result<WebAuthSession>.Failure(ApiError.BadRequest("national_id is required."));
        }

        // POST /api/login-notify {register}. `register` may be РД / civil-id /
        // PNOMN-… — the server resolves any of them. Rate-limited 3/60s per target.
        var body = new LoginNotifyBody(nationalId.Trim());
        try
        {
            using var resp = await _http
                .PostAsJsonAsync("/api/login-notify", body, JsonOptions, ct)
                .ConfigureAwait(false);

            if (!resp.IsSuccessStatusCode)
            {
                return Result<WebAuthSession>.Failure(await MapErrorAsync(resp, ct).ConfigureAwait(false));
            }

            var dto = await resp.Content
                .ReadFromJsonAsync<StartResponse>(JsonOptions, ct)
                .ConfigureAwait(false);

            return BuildSession(dto, deviceLinkFromQr: false);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            return Result<WebAuthSession>.Failure(ApiError.Cancelled("Initiate cancelled."));
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Web auth initiate network error");
            return Result<WebAuthSession>.Failure(ApiError.Network("Initiate network error.", ex.Message));
        }
    }

    public async Task<Result<WebAuthSession>> InitiateQrAsync(CancellationToken ct = default)
    {
        try
        {
            // POST /api/start → {sessionId, qr, deviceLinkBase, vc, pollToken}.
            // `qr` == sessionId (what the mobile app scans + approves).
            using var resp = await _http
                .PostAsJsonAsync("/api/start", new { }, JsonOptions, ct)
                .ConfigureAwait(false);

            if (!resp.IsSuccessStatusCode)
            {
                return Result<WebAuthSession>.Failure(await MapErrorAsync(resp, ct).ConfigureAwait(false));
            }

            var dto = await resp.Content
                .ReadFromJsonAsync<StartResponse>(JsonOptions, ct)
                .ConfigureAwait(false);

            return BuildSession(dto, deviceLinkFromQr: true);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            return Result<WebAuthSession>.Failure(ApiError.Cancelled("QR init cancelled."));
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Web auth QR init network error");
            return Result<WebAuthSession>.Failure(ApiError.Network("QR init network error.", ex.Message));
        }
    }

    public async Task<Result<WebAuthSessionStatus>> PollAsync(Guid sessionId, string pollToken, CancellationToken ct = default)
    {
        if (sessionId == Guid.Empty)
        {
            return Result<WebAuthSessionStatus>.Failure(ApiError.BadRequest("sessionId required."));
        }
        if (string.IsNullOrWhiteSpace(pollToken))
        {
            return Result<WebAuthSessionStatus>.Failure(ApiError.BadRequest("pollToken required."));
        }

        // GET /api/status?sessionId=&pollToken=. The server long-holds ~1s then
        // returns; the ViewModel re-polls. pollToken gates PII (name/idNumber).
        var url = string.Create(
            CultureInfo.InvariantCulture,
            $"/api/status?sessionId={Uri.EscapeDataString(sessionId.ToString("D"))}&pollToken={Uri.EscapeDataString(pollToken)}");

        try
        {
            using var resp = await _http.GetAsync(url, ct).ConfigureAwait(false);

            if (!resp.IsSuccessStatusCode)
            {
                return Result<WebAuthSessionStatus>.Failure(await MapErrorAsync(resp, ct).ConfigureAwait(false));
            }

            var dto = await resp.Content
                .ReadFromJsonAsync<StatusResponse>(JsonOptions, ct)
                .ConfigureAwait(false);

            if (dto is null)
            {
                return Result<WebAuthSessionStatus>.Failure(ApiError.Internal("Backend returned empty body."));
            }

            return Result<WebAuthSessionStatus>.Success(MapStatus(sessionId, dto));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            return Result<WebAuthSessionStatus>.Failure(ApiError.Cancelled("Poll cancelled."));
        }
        catch (HttpRequestException ex)
        {
            _logger.LogWarning(ex, "Web auth poll network error");
            return Result<WebAuthSessionStatus>.Failure(ApiError.Network("Poll network error.", ex.Message));
        }
    }

    // ── USB hardware-token web login (M9.B) ──────────────────────────────────
    // No first-party `/api/*` equivalent exists (there is no `/token/challenge`
    // or `/token/verify` on the web backend). Surfaced as an explicit, honest
    // failure so the "Токен" login tab degrades cleanly instead of 404-ing.

    public Task<Result<WebTokenChallenge>> InitiateTokenChallengeAsync(CancellationToken ct = default)
        => Task.FromResult(Result<WebTokenChallenge>.Failure(
            ApiError.Internal("token_login_not_available_on_first_party_backend")));

    public Task<Result<WebTokenLoginResult>> VerifyTokenAsync(
        Guid sessionId,
        string certPem,
        byte[] signature,
        WebTokenSignatureAlg signatureAlg,
        CancellationToken ct = default)
        => Task.FromResult(Result<WebTokenLoginResult>.Failure(
            ApiError.Internal("token_login_not_available_on_first_party_backend")));

    public async Task<Result> LogoutAsync(CancellationToken ct = default)
    {
        // First-party model has no server-side session/bearer to revoke — the
        // citizen's identity was only ever held client-side. Just wipe local state.
        _identity.Clear();
        await _sessions.ClearAsync(ct).ConfigureAwait(false);
        return Result.Success();
    }

    private static Result<WebAuthSession> BuildSession(StartResponse? dto, bool deviceLinkFromQr)
    {
        if (dto is null || string.IsNullOrWhiteSpace(dto.SessionId))
        {
            return Result<WebAuthSession>.Failure(ApiError.Internal("Backend returned empty session."));
        }
        if (!Guid.TryParse(dto.SessionId, out var sid))
        {
            return Result<WebAuthSession>.Failure(ApiError.Internal("Backend session id was not a UUID."));
        }

        // QR mode: the QR payload is `qr` (== sessionId). Push mode: no QR.
        var deviceLink = deviceLinkFromQr ? (dto.Qr ?? dto.SessionId) : null;

        return Result<WebAuthSession>.Success(new WebAuthSession(
            sid,
            dto.Vc ?? string.Empty,
            dto.PollToken ?? string.Empty,
            DateTimeOffset.UtcNow.Add(SessionTtl),
            deviceLink));
    }

    private WebAuthSessionStatus MapStatus(Guid sessionId, StatusResponse dto)
    {
        // Local session state machine (server/internal/domain/enums.go):
        //   state:     RUNNING (keep polling) | COMPLETE (terminal)
        //   endResult: OK | TIMEOUT | USER_REFUSED* | WRONG_VC | FAILED | …
        var state = (dto.State ?? string.Empty).ToUpperInvariant();
        if (state != "COMPLETE")
        {
            // RUNNING / anything transient → keep polling.
            return new WebAuthSessionStatus(WebAuthState.Pushed, null, null, null, null);
        }

        var end = (dto.EndResult ?? string.Empty).ToUpperInvariant();
        if (end == "OK")
        {
            // First-party bridge: identity arrives inline; there is no bearer.
            // Synthesize a stable-per-session token + user id and cache the
            // profile so UserProfileService.GetMeAsync can serve it.
            var userId = Guid.NewGuid();
            _identity.Set(new UserProfile(
                userId,
                dto.IdNumber ?? string.Empty,
                dto.Name ?? string.Empty,
                FullNameLatin: string.Empty,
                KycLevel: dto.CertificateLevel ?? string.Empty,
                Status: "active",
                CreatedAt: DateTimeOffset.UtcNow));

            return new WebAuthSessionStatus(
                WebAuthState.Confirmed,
                SessionToken: sessionId.ToString("D"),
                UserId: userId,
                FailureReason: null,
                ExpiresAt: DateTimeOffset.UtcNow.Add(SessionTtl));
        }

        if (end == "TIMEOUT")
        {
            return new WebAuthSessionStatus(WebAuthState.Expired, null, null, "timeout", null);
        }

        // USER_REFUSED*, WRONG_VC, FAILED, DOCUMENT_UNUSABLE, … → failed.
        return new WebAuthSessionStatus(
            WebAuthState.Failed,
            null,
            null,
            string.IsNullOrWhiteSpace(dto.Error) ? end.ToLowerInvariant() : dto.Error,
            null);
    }

    private static async Task<ApiError> MapErrorAsync(HttpResponseMessage resp, CancellationToken ct)
    {
        string? body = null;
        BackendError? parsed = null;
        try
        {
            body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (body.Length > 0)
            {
                try { parsed = JsonSerializer.Deserialize<BackendError>(body, JsonOptions); }
                catch (JsonException) { }
            }
        }
        catch { }

        var msg = string.IsNullOrWhiteSpace(parsed?.Error) ? body : parsed!.Error;

        return resp.StatusCode switch
        {
            HttpStatusCode.NotFound          => ApiError.NotFound(msg ?? "not_found", body),
            HttpStatusCode.BadRequest        => ApiError.BadRequest(msg ?? "invalid_body", body),
            HttpStatusCode.Unauthorized      => ApiError.Unauthorized(msg ?? "unauthenticated", body),
            (HttpStatusCode)429              => ApiError.BadRequest(msg ?? "rate_limited", body),
            HttpStatusCode.RequestTimeout    => ApiError.Timeout(msg ?? "timeout", body),
            _ when (int)resp.StatusCode >= 500 => ApiError.Server(msg ?? $"server_{(int)resp.StatusCode}", body),
            _ => ApiError.Internal(msg ?? $"unexpected_{(int)resp.StatusCode}", body),
        };
    }

    // ── Wire DTOs (camelCase; JsonSerializerDefaults.Web matches case-insensitively) ──

    private sealed record LoginNotifyBody(
        [property: JsonPropertyName("register")] string Register);

    /// Shared shape of /api/start and /api/login-notify responses.
    private sealed record StartResponse(
        [property: JsonPropertyName("sessionId")] string? SessionId,
        [property: JsonPropertyName("qr")] string? Qr,
        [property: JsonPropertyName("deviceLinkBase")] string? DeviceLinkBase,
        [property: JsonPropertyName("vc")] string? Vc,
        [property: JsonPropertyName("pollToken")] string? PollToken);

    private sealed record StatusResponse(
        [property: JsonPropertyName("state")] string? State,
        [property: JsonPropertyName("endResult")] string? EndResult,
        [property: JsonPropertyName("name")] string? Name,
        [property: JsonPropertyName("idNumber")] string? IdNumber,
        [property: JsonPropertyName("documentNumber")] string? DocumentNumber,
        [property: JsonPropertyName("certificateLevel")] string? CertificateLevel,
        [property: JsonPropertyName("error")] string? Error);

    private sealed record BackendError(
        [property: JsonPropertyName("error")] string? Error);
}

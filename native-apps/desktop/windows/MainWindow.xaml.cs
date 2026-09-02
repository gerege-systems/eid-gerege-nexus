using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using Microsoft.Web.WebView2.Core;
using QRCoder;
using System.IO;
using System.Windows.Media.Imaging;

namespace GeregeNexusNativeWin
{
    /// <summary>
    /// Аппын цорын ганц цонх.
    ///
    /// Дүрэм: <b>popup-аас бусад бүх зүйл энэ хүрээн дотор</b>. Нэвтрэлт, ажлын
    /// муж, тохиргоо гурвуул нэг цонхны дотор солигддог дэлгэцүүд. Тусдаа
    /// Window нээх эрхтэй зүйл бол зөвхөн MessageBox болон файл сонгох диалог
    /// гэх мэт богино насалдаг popup-ууд.
    ///
    /// Ажлын муж нь <c>desktop.eid.gerege.mn</c> — ширээний domain шугам. Тэр
    /// host нь өөрийн <c>/api/v1</c>-ээ мөн үйлчилдэг тул webview доторх
    /// дуудлага same-origin болж, session cookie нь SameSite=Strict хэвээр
    /// ажиллана.
    /// </summary>
    public partial class MainWindow : Window
    {
        /// <summary>Хүрээн доторх дэлгэцүүд. Шинэ native дэлгэц нэмэх гэж
        /// байвал энд нэмнэ — цонх нэмэхгүй.</summary>
        private enum Pane { Work, Settings }

        private readonly NativeSettings _settings = NativeSettings.Load();
        private readonly string _baseUrl;
        private NativeIPCBridge? _ipcBridge;
        private readonly NativeAuth _auth;
        private SettingsPane? _settingsPane;
        public string WebOrigin => new Uri(_baseUrl).GetLeftPart(UriPartial.Authority);

        public MainWindow()
        {
            _baseUrl = _settings.WebEndpoint.TrimEnd('/');
            _auth = new NativeAuth(_settings.ApiEndpoint);
            InitializeComponent();
            footerHost.Text = new Uri(_baseUrl).Host;
            footerVersion.Text = ShellVersion();
            emailInput.ToolTip=NativeStrings.Get("auth_field_email","И-мэйл");passwordInput.ToolTip=NativeStrings.Get("auth_field_password","Нууц үг");passwordLoginButton.Content=NativeStrings.Get("auth_action_admin_sign_in","Админаар нэвтрэх");nationalIdInput.ToolTip=NativeStrings.Get("auth_eid_reg_number","Регистрийн дугаар");pushLoginButton.Content=NativeStrings.Get("auth_eid_send_request","eID апп руу хүсэлт илгээх");cancelLoginButton.Content=NativeStrings.Get("auth_action_cancel","Цуцлах");staffPinButton.Content=NativeStrings.Get("auth_action_staff_sign_in","Ээлжийн ажилтнаар нэвтрэх");
            staffPinPanel.Visibility = ShellProfile.FormFactor == "pos" ? Visibility.Visible : Visibility.Collapsed;
            _auth.StatusChanged += status => Dispatcher.Invoke(() => RenderLogin(status));
            BindShortcuts();
            InitializeWebViewAsync();
        }

        /// <summary>
        /// Footer-т харагдах хувилбар — "v1.0.9 (10)" хэлбэрээр, macOS-ийнхтэй
        /// ижил: маркетингийн хувилбар ба build дугаар. Эхнийх нь csproj-ийн
        /// Version, хоёр дахь нь AssemblyVersion-ий 4 дэх орон.
        /// </summary>
        private static string ShellVersion()
        {
            var assembly = System.Reflection.Assembly.GetEntryAssembly();
            var informational = System.Reflection.CustomAttributeExtensions
                .GetCustomAttribute<System.Reflection.AssemblyInformationalVersionAttribute>(assembly!)?
                .InformationalVersion ?? "1.0.0";
            // "1.0.9+<commit>" хэлбэртэй ирж болзошгүй.
            var marketing = informational.Split('+')[0];
            var build = assembly?.GetName().Version?.Revision ?? 0;
            return $"v{marketing} ({build})";
        }

        /// <summary>
        /// Цэсэн дэх товчлолуудыг ЖИНХЭНЭ болгоно.
        ///
        /// XAML дахь <c>InputGestureText</c> нь зөвхөн бичээс — WPF түүнээс
        /// товчлол үүсгэдэггүй. Тиймээс цэс нь Ctrl+L, Ctrl+, гэх мэтийг
        /// амласан ч дарахад юу ч болдоггүй байв. macOS тал дээр эдгээр нь
        /// цэсний keyEquivalent-ээр жинхэнэ ажилладаг.
        /// </summary>
        private void BindShortcuts()
        {
            void Bind(Key key, ModifierKeys modifiers, Action action) =>
                InputBindings.Add(new KeyBinding(new ShellCommand(action), key, modifiers));

            Bind(Key.L, ModifierKeys.Control, ShowNativeLogin);
            Bind(Key.OemComma, ModifierKeys.Control, () => { if (navRail.Visibility == Visibility.Visible) ShowPane(Pane.Settings); });
            Bind(Key.D0, ModifierKeys.Control, () => { if (navRail.Visibility == Visibility.Visible) ShowPane(Pane.Work); });
            Bind(Key.H, ModifierKeys.Control, () => NavigatePath(ShellProfile.StartRoute));
            Bind(Key.D1, ModifierKeys.Control, () => NavigatePath("/apps"));
            Bind(Key.F5, ModifierKeys.None, () => webView?.Reload());
            Bind(Key.F11, ModifierKeys.None, ToggleFullScreen);
        }

        /// <summary>Товчлолд зориулсан хамгийн бага ICommand.</summary>
        private sealed class ShellCommand : ICommand
        {
            private readonly Action _action;
            public ShellCommand(Action action) => _action = action;
            public event EventHandler? CanExecuteChanged { add { } remove { } }
            public bool CanExecute(object? parameter) => true;
            public void Execute(object? parameter) => _action();
        }

        private async void InitializeWebViewAsync()
        {
            try
            {
                await webView.EnsureCoreWebView2Async(null);

                // Initialize Native C# IPC Bridge
                _ipcBridge = new NativeIPCBridge(webView, this);

                // Нэвтрэлтийн клиентийг ажлын мужтай ижил User-Agent дээр
                // тавина — session нь клиентийн хүрээнд баригдсан тохиолдолд
                // хуулсан cookie хүчингүй болохоос сэргийлнэ.
                _auth.UseUserAgent(webView.CoreWebView2.Settings.UserAgent);

                // Inject Native Bridge JS initializer into every document created
                await webView.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(@"
                  (() => {
                    if (window.GeregeShell) return;
                    const pending=new Map(),listeners=new Map(); let sequence=0;
                    window.__geregeShellResolve=(id,ok,value)=>{const p=pending.get(id);if(!p)return;pending.delete(id);ok?p.resolve(value):p.reject(new Error(String(value)))};
                    window.__geregeShellEmit=(name,payload)=>(listeners.get(name)||[]).slice().forEach(fn=>fn(payload));
                    window.GeregeShell=Object.freeze({version:'1.4',platform:'windows',formFactor:'" + ShellProfile.FormFactor + @"',capabilities:Object.freeze(" + System.Text.Json.JsonSerializer.Serialize(ShellProfile.Capabilities) + @"),
                      invoke(method,params={}){return new Promise((resolve,reject)=>{const id=String(++sequence);pending.set(id,{resolve,reject});window.chrome.webview.postMessage(JSON.stringify({id,method,params}))})},
                      on(name,handler){const list=listeners.get(name)||[];list.push(handler);listeners.set(name,list);return()=>{const i=list.indexOf(handler);if(i>=0)list.splice(i,1)}}});
                    document.documentElement.setAttribute('data-shell','windows');
                  })();");

                // Listen to IPC messages sent from WebView2
                webView.CoreWebView2.WebMessageReceived += (s, e) =>
                {
                    string message = e.TryGetWebMessageAsString();
                    if (!string.IsNullOrEmpty(message))
                    {
                        _ipcBridge.HandleWebMessage(message, e.Source);
                    }
                };

                webView.CoreWebView2.NavigationStarting += NavigationStarting;
                // Буцах товч нь түүх байхгүй үед идэвхгүй байна.
                webView.CoreWebView2.HistoryChanged += (_, _) =>
                    ribbonBack.IsEnabled = webView.CoreWebView2.CanGoBack;
                // target="_blank" болон window.open нь хүрээнээс тасарсан хоёр
                // дахь webview цонх нээхийг хүсдэг. Handled=true нь тэр цонхыг
                // үүсгэхгүй гэсэн үг — хаяг нь зөвшөөрөгдсөн scheme-тэй бол
                // системийн хөтчөөр нээгдэнэ.
                webView.CoreWebView2.NewWindowRequested += (_, e) =>
                {
                    e.Handled = true;
                    if (Uri.TryCreate(e.Uri, UriKind.Absolute, out var target) && target.Scheme is "http" or "https" or "mailto" or "tel")
                        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(target.AbsoluteUri) { UseShellExecute = true });
                };
                // Холбогдсон төлөвийн өнгө нь дизайн системийн chromeAccent
                // (Brand300) — өмнөх #62D9D4 нь ramp-д байхгүй, macOS-оос
                // зөрдөг өнгө байв.
                webView.CoreWebView2.NavigationCompleted += async (_, e) =>
                {
                    footerHost.Text = new Uri(webView.Source.ToString()).Host;
                    // Холболт тасрахад host-ийн хажууд шалтгаан гарна; амжилттай
                    // үед мэдэгдэл алга болно.
                    footerNotice.Text = e.IsSuccess ? string.Empty : "Холболт тасарсан";
                    footerNotice.Foreground = (System.Windows.Media.Brush)FindResource("EidDangerBrush");
                    footerNotice.Visibility = e.IsSuccess ? Visibility.Collapsed : Visibility.Visible;
                    _ = webView.CoreWebView2.ExecuteScriptAsync("window.__geregeShellEmit&&window.__geregeShellEmit('shell:auth-changed',{reason:'navigation-session'})");
                    ShellLog.Write($"nav: {webView.Source} success={e.IsSuccess}");
                    try
                    {
                        // Ажлын мужид ямар cookie байгаа нь session дамжуулалт
                        // бүтсэн эсэхийг хожим оношлоход хэрэгтэй.
                        var jar = await webView.CoreWebView2.CookieManager.GetCookiesAsync(_baseUrl);
                        ShellLog.Write($"nav: cookie {jar.Count}ш — " + string.Join(", ", jar.Select(c => $"{c.Name}(path={c.Path})")));
                    }
                    catch (System.Runtime.InteropServices.COMException error)
                    {
                        ShellLog.Write($"nav: cookie уншилт амжилтгүй — {error.Message}");
                    }
                };
                var deviceToken = CredentialManagerTokenStore.Load();
                if (!string.IsNullOrWhiteSpace(deviceToken))
                {
                    var api = new Uri(_settings.ApiEndpoint);
                    var cookie = webView.CoreWebView2.CookieManager.CreateCookie("device_token", deviceToken, api.Host, "/api/v1/devices");
                    cookie.IsHttpOnly = true; cookie.IsSecure = api.Scheme == "https"; webView.CoreWebView2.CookieManager.AddOrUpdateCookie(cookie);
                    _ = new DeviceEnrollmentClient().TelemetryAsync(_settings.ApiEndpoint,deviceToken,"INFO","shell.started",new{form_factor=ShellProfile.FormFactor,runtime="webview2"});
                }
                if (ShellProfile.FormFactor == "kiosk" && !string.IsNullOrWhiteSpace(deviceToken)) { EnterShell(); NavigatePath(ShellProfile.StartRoute); EnterKioskMode(); }
                else ShowNativeLogin();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"WebView2 Initialization Error: {ex.Message}", "eID Gerege", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        public void NavigatePath(string relativePath)
        {
            if (webView != null && webView.CoreWebView2 != null)
            {
                // Ажлын муж руу чиглэсэн шилжилт нь ажлын мужийг ХАРУУЛНА. Үгүй
                // бол цэснээс "Апп дэлгүүр" дарахад хуудас нь нууц ачаалагдаад
                // хэрэглэгч тохиргоон дээрээ үлддэг.
                if (navRail.Visibility == Visibility.Visible) ShowPane(Pane.Work);
                string targetUrl = _baseUrl + relativePath;
                webView.CoreWebView2.Navigate(targetUrl);
            }
        }

        /// <summary>
        /// Нэвтрэлт нь мөн энэ хүрээний дэлгэц: chrome-ыг нуугаад бүтнээр нь
        /// бүрхэнэ. Тусдаа нэвтрэх цонх нээгдэхгүй.
        /// </summary>
        public void ShowNativeLogin()
        {
            loginView.Visibility = Visibility.Visible;
            webView.Visibility = Visibility.Collapsed;
            settingsHost.Visibility = Visibility.Collapsed;
            navRail.Visibility = Visibility.Collapsed;
            ribbon.Visibility = Visibility.Collapsed;
            nativeFooter.Visibility = Visibility.Collapsed;
            ApplyHeroWidth();
        }

        /// <summary>Нэвтэрсний дараа bürхүүлийн chrome-ыг гаргаж, ажлын муж дээр
        /// эхэлнэ.</summary>
        private void EnterShell()
        {
            loginView.Visibility = Visibility.Collapsed;
            navRail.Visibility = Visibility.Visible;
            ribbon.Visibility = Visibility.Visible;
            nativeFooter.Visibility = Visibility.Visible;
            var profile = _auth.Profile ?? NativeUserProfile.EidUser;
            var name = string.IsNullOrWhiteSpace(profile.Name) ? "Хэрэглэгч" : profile.Name;
            profileButton.Content = "◍   " + name;
            profileMenuName.Header = name;
            profileMenuEmail.Header = profile.Email;
            profileMenuEmail.Visibility = string.IsNullOrWhiteSpace(profile.Email)
                ? Visibility.Collapsed : Visibility.Visible;
            ShowPane(Pane.Work);
        }

        /// <summary>
        /// Профайлын цэс — нэр, и-мэйл, Тохиргоо…, Гарах (macOS-ийн NSMenu).
        /// </summary>
        private void ProfileButton_Click(object sender, RoutedEventArgs e)
        {
            if (profileButton.ContextMenu is not { } menu) return;
            menu.PlacementTarget = profileButton;
            menu.Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom;
            menu.IsOpen = true;
        }

        /// <summary>
        /// Session-ийг серверт хааж, cookie-г цэвэрлээд нэвтрэх дэлгэц рүү
        /// буцна (macOS-ийн logout + clearSessionAndShowLogin).
        /// </summary>
        private async void MenuLogout_Click(object sender, RoutedEventArgs e)
        {
            await _auth.LogoutAsync();
            if (webView.CoreWebView2 is { } core)
            {
                // session_token-ийг webview-ийн cookie сангаас ч устгана — эс
                // бөгөөс ажлын муж дараагийн ачаалалт дээр нэвтэрсэн хэвээр
                // сэргэнэ.
                var cookies = await core.CookieManager.GetCookiesAsync(_baseUrl);
                foreach (var cookie in cookies)
                {
                    if (cookie.Name == "session_token") core.CookieManager.DeleteCookie(cookie);
                }
            }
            ShowNativeLogin();
        }

        /// <summary>Ажлын мужийн түүхээр нэг алхам буцна.</summary>
        private void RibbonBack_Click(object sender, RoutedEventArgs e)
        {
            if (webView?.CoreWebView2 is { CanGoBack: true } core) core.GoBack();
        }

        /// <summary>
        /// Цонх 820-аас нарийсвал зүүн талын брэнд талбар алга болж, карт
        /// цонхыг бүтнээр эзэлнэ — macOS-ийн viewDidLayout дахь босго.
        /// </summary>
        private void Window_SizeChanged(object sender, SizeChangedEventArgs e) => ApplyHeroWidth();

        private void ApplyHeroWidth()
        {
            if (heroPanel is null || heroColumn is null) return;
            var wide = ActualWidth >= 820;
            heroPanel.Visibility = wide ? Visibility.Visible : Visibility.Collapsed;
            heroColumn.Width = wide ? new GridLength(5, GridUnitType.Star) : new GridLength(0);
        }

        /// <summary>Хүрээн доторх дэлгэцийг солино. Цонх нээхгүй, цонх хаахгүй.</summary>
        private void ShowPane(Pane pane)
        {
            if (pane == Pane.Settings && _settingsPane == null)
            {
                _settingsPane = new SettingsPane();
                // Шинэ хаяг руу шууд шилжүүлэхгүй. _baseUrl нь эхлэхэд уншигдаж,
                // cookie store, navigation allowlist, гүүрийн origin шалгалт
                // гурвуул тэр утган дээр тогтсон байдаг — зөвхөн хуудсыг
                // ачаалах нь тэднийг зөрүүтэй үлдээж, гүүр чимээгүй унтардаг.
                // Тиймээс хэрэглэгчид үнэнийг нь хэлнэ.
                _settingsPane.EndpointsChanged += () =>
                {
                    footerNotice.Text = "Шинэ хаяг аппыг дахин эхлүүлсний дараа хэрэгжинэ";
                    footerNotice.Foreground = (System.Windows.Media.Brush)FindResource("EidWarningBrush");
                    footerNotice.Visibility = Visibility.Visible;
                };
                settingsHost.Content = _settingsPane;
            }
            webView.Visibility = pane == Pane.Work ? Visibility.Visible : Visibility.Collapsed;
            settingsHost.Visibility = pane == Pane.Settings ? Visibility.Visible : Visibility.Collapsed;

            // Rail-ын идэвхтэй/идэвхгүй өнгө нь дизайн системийн chromeAccent
            // (Brand300) ба chromeMuted — өмнө нь ramp-д байхгүй ногоон-цэнхэр
            // байсан нь macOS-оос зөрж байв.
            var active = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x84, 0xA8, 0xFF));
            var idle = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x94, 0xA3, 0xB8));
            navWorkButton.Foreground = pane == Pane.Work ? active : idle;
            navSettingsButton.Foreground = pane == Pane.Settings ? active : idle;
        }

        private void NavWork_Click(object sender, RoutedEventArgs e)
        {
            if (navRail.Visibility == Visibility.Visible) ShowPane(Pane.Work);
        }

        private void NavSettings_Click(object sender, RoutedEventArgs e)
        {
            if (navRail.Visibility == Visibility.Visible) ShowPane(Pane.Settings);
        }

        /// <summary>Гүүрийн <c>shell.openPane</c> эндээс ордог — ижил хүрээн
        /// доторх дэлгэц солигдоно.</summary>
        public bool OpenPane(string pane)
        {
            if (navRail.Visibility != Visibility.Visible) return false;
            switch (pane)
            {
                case "settings": ShowPane(Pane.Settings); return true;
                case "work": ShowPane(Pane.Work); return true;
                default: return false;
            }
        }

        private async void PasswordLogin_Click(object sender, RoutedEventArgs e) =>
            await _auth.PasswordAsync(emailInput.Text, passwordInput.Password);

        private async void PushLogin_Click(object sender, RoutedEventArgs e) =>
            await _auth.PushAsync(nationalIdInput.Text);

        // ── Нэвтрэх дэлгэцийн таб (macOS-ийн select(_:)) ──────────────────
        //
        // РД таб нь оролтын талбарыг, QR таб нь кодыг харуулна. QR руу
        // шилжихэд session шууд эхэлж, буцахад цуцлагдана.

        private async void QrTab_Click(object sender, RoutedEventArgs e)
        {
            SelectTab(qr: true);
            await _auth.QrAsync();
        }

        private void IdTab_Click(object sender, RoutedEventArgs e)
        {
            SelectTab(qr: false);
            _auth.Cancel();
        }

        private void SelectTab(bool qr)
        {
            idTab.IsChecked = !qr;
            qrTab.IsChecked = qr;
            idSection.Visibility = qr ? Visibility.Collapsed : Visibility.Visible;
            qrSection.Visibility = qr ? Visibility.Visible : Visibility.Collapsed;
        }

        /// <summary>Админаар нэвтрэх хэсгийг нээх/хаах — macOS-ийн toggleAdmin.</summary>
        private void AdminToggle_Click(object sender, RoutedEventArgs e) =>
            adminSection.Visibility = adminSection.Visibility == Visibility.Visible
                ? Visibility.Collapsed : Visibility.Visible;

        /// <summary>
        /// Алдааг пастел мөрөнд харуулна (macOS-ийн InlineBanner). Өмнө нь
        /// алдаа status мөрөнд түүхийгээрээ бичигддэг тул серверийн техникийн
        /// текст шууд иргэнд харагддаг байв.
        /// </summary>
        private void ShowLoginError(string message)
        {
            loginStatus.Text = string.Empty;
            loginBannerText.Text = message;
            loginBanner.Visibility = Visibility.Visible;
        }

        private async void StaffPin_Click(object sender, RoutedEventArgs e)
        {
            var token = CredentialManagerTokenStore.Load();
            if (string.IsNullOrWhiteSpace(token)) { loginStatus.Text = "Эхлээд төхөөрөмжийг enrollment code-оор бүртгэнэ үү"; return; }
            await _auth.StaffPinAsync(staffPinInput.Password, token);
        }

        private void CancelLogin_Click(object sender, RoutedEventArgs e) => _auth.Cancel();

        private void RenderLogin(LoginStatus status)
        {
            var pending = status.Phase is LoginPhase.Starting or LoginPhase.Waiting;
            loginBanner.Visibility = Visibility.Collapsed;
            if (status.Phase is LoginPhase.Expired or LoginPhase.Refused or LoginPhase.Error)
            {
                ShowLoginError(status.Message);
            }
            else
            {
                loginStatus.Text = status.Message;
            }
            passwordLoginButton.IsEnabled = !pending; pushLoginButton.IsEnabled = !pending;
            idTab.IsEnabled = !pending; qrTab.IsEnabled = !pending;
            if (pending && !string.IsNullOrWhiteSpace(_auth.LastDeviceLinkUrl)) { using var data = QRCodeGenerator.GenerateQrCode(_auth.LastDeviceLinkUrl, QRCodeGenerator.ECCLevel.Q); var bytes = new PngByteQRCode(data).GetGraphic(8); var bitmap = new BitmapImage(); using var stream = new MemoryStream(bytes); bitmap.BeginInit(); bitmap.CacheOption = BitmapCacheOption.OnLoad; bitmap.StreamSource = stream; bitmap.EndInit(); bitmap.Freeze(); qrImage.Source = bitmap; }
            else if (!pending) qrImage.Source = null;
            cancelLoginButton.Visibility = pending ? Visibility.Visible : Visibility.Collapsed;
            if (status.Phase != LoginPhase.Success || webView.CoreWebView2 == null) return;
            _ = HandOverSessionAsync();
        }

        /// <summary>
        /// Нэвтрэлтийн session-ийг ажлын мужид дамжуулна.
        ///
        /// Гурван зүйлийг хамтад нь хийнэ:
        ///   • cookie-г серверийн өгсөн замаар нь ба "/" замаар хуулна — зам нь
        ///     <c>/api/v1</c> байвал хуудсыг өөрийг нь татах хүсэлт cookie-гүй
        ///     явж, сервер нэвтрээгүй гэж үзнэ;
        ///   • DevTools протоколоор сүлжээний давхарга руу шууд бичнэ —
        ///     CookieManager-ын бичилт эхний хүсэлтэд амжихгүй байх
        ///     магадлалыг хаана;
        ///   • бичилтийн дараа нэг уншилт хийж дарааллыг батална.
        /// </summary>
        private async Task HandOverSessionAsync()
        {
            var manager = webView.CoreWebView2.CookieManager;
            var host = new Uri(_baseUrl).Host;
            var shellCookies = _auth.SessionCookies;
            ShellLog.Write($"handover: бүрхүүлд {shellCookies.Count} cookie байна");
            foreach (System.Net.Cookie source in shellCookies)
            {
                ShellLog.Write($"handover: {source.Name} domain={source.Domain} path={source.Path} secure={source.Secure} httpOnly={source.HttpOnly}");
                var domain = string.IsNullOrWhiteSpace(source.Domain) ? host : source.Domain;
                Copy(source, domain, source.Path);
                if (source.Path != "/") Copy(source, domain, "/");
                await SetViaDevToolsAsync(source, domain);
            }

            try { _ = await manager.GetCookiesAsync(_baseUrl); }
            catch (System.Runtime.InteropServices.COMException error)
            {
                ShellLog.Write($"handover: cookie уншилт амжилтгүй — {error.Message}");
            }

            EnterShell();
            NavigatePath(ShellProfile.StartRoute);

            async Task SetViaDevToolsAsync(System.Net.Cookie source, string domain)
            {
                try
                {
                    var parameters = System.Text.Json.JsonSerializer.Serialize(new
                    {
                        name = source.Name,
                        value = source.Value,
                        domain,
                        path = string.IsNullOrEmpty(source.Path) ? "/" : source.Path,
                        secure = source.Secure,
                        httpOnly = source.HttpOnly,
                        sameSite = "Lax",
                    });
                    await webView.CoreWebView2.CallDevToolsProtocolMethodAsync("Network.setCookie", parameters);
                }
                catch (Exception error)
                {
                    ShellLog.Write($"handover: CDP setCookie амжилтгүй — {error.Message}");
                }
            }

            void Copy(System.Net.Cookie source, string domain, string path)
            {
                var cookie = manager.CreateCookie(source.Name, source.Value, domain, path);
                cookie.IsHttpOnly = source.HttpOnly;
                cookie.IsSecure = source.Secure;
                if (source.Expires != DateTime.MinValue) cookie.Expires = source.Expires;
                manager.AddOrUpdateCookie(cookie);
            }
        }

        private void NavigationStarting(object? sender, CoreWebView2NavigationStartingEventArgs e)
        {
            if (Uri.TryCreate(e.Uri, UriKind.Absolute, out var uri) && uri.GetLeftPart(UriPartial.Authority) == _baseUrl) return;
            e.Cancel = true;
            if (uri?.Scheme is "http" or "https" or "mailto" or "tel")
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(uri.AbsoluteUri) { UseShellExecute = true });
        }

        private void MenuAbout_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show(
                "eID Gerege (Windows)\n\nGerege Nexus native shell v1.0\nBuilt on C# .NET 8 + WPF + WebView2",
                "eID Gerege",
                MessageBoxButton.OK,
                MessageBoxImage.Information
            );
        }

        private void MenuLogin_Click(object sender, RoutedEventArgs e)
        {
            ShowNativeLogin();
        }

        private void MenuSettings_Click(object sender, RoutedEventArgs e)
        {
            // Өмнө нь энэ нь `new SettingsWindow(this).ShowDialog()` байсан —
            // modal тусдаа цонх. Одоо ижил хүрээн доторх дэлгэц.
            if (navRail.Visibility == Visibility.Visible) ShowPane(Pane.Settings);
        }

        /// <summary>
        /// Шугамын нүүр — хатуу "/" биш <see cref="ShellProfile.StartRoute"/>.
        /// "/" нь нийтийн танилцуулга хуудас байх боломжтой тул нэвтэрсэн
        /// хэрэглэгчийг тэр рүү гаргах нь буруу.
        /// </summary>
        private void MenuLineHome_Click(object sender, RoutedEventArgs e)
        {
            NavigatePath(ShellProfile.StartRoute);
        }

        private void MenuApps_Click(object sender, RoutedEventArgs e)
        {
            NavigatePath("/apps");
        }

        private void MenuReload_Click(object sender, RoutedEventArgs e)
        {
            webView?.Reload();
        }

        private void MenuFullScreen_Click(object sender, RoutedEventArgs e) => ToggleFullScreen();

        private void ToggleFullScreen()
        {
            if (WindowState == WindowState.Maximized)
            {
                WindowState = WindowState.Normal;
                WindowStyle = WindowStyle.SingleBorderWindow;
            }
            else
            {
                WindowStyle = WindowStyle.None;
                WindowState = WindowState.Maximized;
            }
        }

        private void EnterKioskMode() { WindowStyle = WindowStyle.None; WindowState = WindowState.Maximized; Topmost = true; }
        public void SetKioskMode(bool enabled) { if(enabled) EnterKioskMode(); else { Topmost=false;WindowState=WindowState.Normal;WindowStyle=WindowStyle.SingleBorderWindow; } }

        private void MenuExit_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}

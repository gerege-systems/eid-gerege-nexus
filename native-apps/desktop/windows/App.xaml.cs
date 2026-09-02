using System;
using System.Globalization;
using System.Windows;

namespace GeregeNexusNativeWin
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// Pure Native C# .NET 8 WPF Shell
    /// </summary>
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            ApplyLanguage();
            AppDomain.CurrentDomain.UnhandledException += (s, ev) =>
            {
                MessageBox.Show($"Unhandled Error: {ev.ExceptionObject}", "eID Gerege — алдаа", MessageBoxButton.OK, MessageBoxImage.Error);
            };
        }

        /// <summary>
        /// Тохиргоон дахь хэлийг мөрийн сан руу тавина.
        ///
        /// Үүнгүйгээр ResourceManager нь ОС-ийн хэлээр шийддэг байсан:
        /// Тохиргооноос "mn" сонгосон ч Windows нь англи бол `NativeStrings`
        /// англи мөр буцааж, XAML дахь монгол бичвэртэй хольж харуулдаг байв
        /// (нэг картан дээр хоёр хэл). Хэл нь аппын тохиргоо болохоос ОС-ийнх
        /// биш тул энд шийднэ.
        /// </summary>
        private static void ApplyLanguage()
        {
            try
            {
                var language = NativeSettings.Load().Language;
                if (string.IsNullOrWhiteSpace(language)) return;
                var culture = CultureInfo.GetCultureInfo(language);
                CultureInfo.DefaultThreadCurrentUICulture = culture;
                CultureInfo.CurrentUICulture = culture;
            }
            catch (CultureNotFoundException)
            {
                // Танигдахгүй код — ОС-ийн хэл дээр үлдэнэ.
            }
        }
    }
}

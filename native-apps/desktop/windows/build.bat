@echo off
echo ========================================================
echo  Building Native Windows App (C# / .NET 8 WPF / WebView2)
echo ========================================================

cd /d "%~dp0"

dotnet restore eIDGeregeMN.csproj
dotnet build eIDGeregeMN.csproj -c Release

echo.
echo ========================================================
echo  Build Completed Successfully!
echo  Binary output at: bin\Release\Desktop\net8.0-windows*\eIDGeregeMN.Desktop.exe
echo ========================================================

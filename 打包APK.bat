@echo off
chcp 65001 >nul
echo ========================================
echo   KKCODER Mobile - Build APK
echo ========================================
echo.
echo [1/2] Cleaning old build...
flutter clean
echo.
echo [2/2] Building Release APK...
flutter build apk --release
echo.
if %errorlevel% equ 0 (
    echo ========================================
    echo   Build Success!
    echo   APK: build\app\outputs\flutter-apk\app-release.apk
    echo ========================================
    explorer build\app\outputs\flutter-apk
) else (
    echo ========================================
    echo   Build Failed! Check errors above.
    echo ========================================
)
echo.
pause
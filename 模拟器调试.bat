@echo off
chcp 65001 >nul
echo ========================================
echo   KKCODER Mobile - MuMu Emulator Debug
echo ========================================
echo.
echo [1/3] Connecting MuMu Emulator (127.0.0.1:7555)...
adb connect 127.0.0.1:7555
echo.
echo [2/3] Detecting connected devices...
adb devices
echo.
echo [3/3] Starting app in debug mode...
echo.
echo   Hotkeys after app starts:
echo     r - Hot Reload
echo     R - Hot Restart
echo     q - Quit
echo.
flutter run -d 127.0.0.1:7555
pause
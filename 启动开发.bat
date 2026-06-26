@echo off
chcp 65001 >nul
echo ========================================
echo   KKCODER Mobile - Dev Mode
echo ========================================
echo.
echo Detecting connected devices...
flutter devices
echo.
flutter run
pause
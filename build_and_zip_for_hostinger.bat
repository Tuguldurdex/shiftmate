@echo off
echo =======================================
echo ShiftMate Build Script for Hostinger
echo =======================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter and try again
    pause
    exit /b 1
)

echo Step 1: Building Flutter web with CanvasKit renderer...
flutter build web --base-href "/" --web-renderer canvaskit --release

echo.
echo Step 2: Copying .htaccess to build/web...
copy /y "web\.htaccess" "build\web\.htaccess"

echo.
echo Step 3: Creating zip file for Hostinger...
cd build\web
powershell -Command "Compress-Archive -Path '*' -DestinationPath '..\..\shiftmate_hostinger.zip' -Force"
cd ..\..

echo.
echo =======================================
echo Build complete!
echo =======================================
echo.
echo Created: shiftmate_hostinger.zip
echo.
echo Next steps:
echo 1. Upload shiftmate_hostinger.zip to Hostinger
echo 2. Extract it in public_html folder
echo 3. Make sure .htaccess is in the root
echo.
pause

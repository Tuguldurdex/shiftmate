@echo off
chcp 65001 >nul
echo =======================================
echo ShiftMate - Prepare for Hostinger
echo =======================================
echo.

REM Check if Flutter is available
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found in PATH
    echo Please run this on a machine with Flutter installed
    echo Or run: flutter build web --base-href "/" --web-renderer canvaskit --release
    echo Then manually zip the build/web/ folder
    pause
    exit /b 1
)

echo [1/4] Building Flutter web app with CanvasKit...
flutter build web --base-href "/" --web-renderer canvaskit --release

if %errorlevel% neq 0 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

echo [2/4] Adding .htaccess to build folder...
if not exist "build\web\.htaccess" (
    copy "web\.htaccess" "build\web\.htaccess" /Y
)

echo [3/4] Updating index.html with loading spinner...
powershell -Command "& {
    $content = Get-Content 'web\index.html' -Raw;
    $content | Set-Content 'build\web\index.html' -NoNewline
}"

echo [4/4] Creating zip file...
cd build\web
powershell -Command "Compress-Archive -Path '*' -DestinationPath '..\..\shiftmate_hostinger.zip' -Force"
cd ..\..

if exist "shiftmate_hostinger.zip" (
    echo.
    echo =======================================
    echo SUCCESS! Created: shiftmate_hostinger.zip
    echo =======================================
    echo.
    echo Upload this zip to Hostinger and extract in public_html
    echo Make sure .htaccess is in the root directory
) else (
    echo [ERROR] Failed to create zip file
    echo Please manually zip the contents of build\web\ folder
)

echo.
pause

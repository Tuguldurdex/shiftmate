# PowerShell script to create Hostinger-ready zip
# Run this script on your machine after building the Flutter web app

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "ShiftMate - Create Hostinger Zip" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Check if build/web exists
if (-not (Test-Path "build\web")) {
    Write-Host "[ERROR] build\web folder not found!" -ForegroundColor Red
    Write-Host "Please run: flutter build web --base-href '/' --web-renderer canvaskit --release" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Ensure .htaccess exists in build/web
if (-not (Test-Path "build\web\.htaccess")) {
    Write-Host "[1/3] Copying .htaccess to build\web..." -ForegroundColor Yellow
    Copy-Item "web\.htaccess" "build\web\.htaccess" -Force
}

# Ensure index.html has loading spinner
Write-Host "[2/3] Checking index.html for loading spinner..." -ForegroundColor Yellow
$indexPath = "build\web\index.html"
$indexContent = Get-Content $indexPath -Raw
if (-not ($indexContent -match "loading-indicator")) {
    Write-Host "  Updating index.html with loading spinner..." -ForegroundColor Yellow
    Copy-Item "web\index.html" $indexPath -Force
}

# Create zip file
Write-Host "[3/3] Creating zip file..." -ForegroundColor Yellow
$zipPath = "shiftmate_hostinger.zip"

# Remove existing zip if exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Create zip from build/web contents (not the folder itself)
$sourcePath = "build\web\*"
try {
    Compress-Archive -Path $sourcePath -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host "SUCCESS! Created: $zipPath" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Upload $zipPath to Hostinger" -ForegroundColor White
    Write-Host "2. Extract it in public_html folder" -ForegroundColor White
    Write-Host "3. Make sure .htaccess is in the root directory" -ForegroundColor White
} catch {
    Write-Host "[ERROR] Failed to create zip: $_" -ForegroundColor Red
    Write-Host "Please manually zip the contents of build\web\ folder" -ForegroundColor Yellow
}

Read-Host "Press Enter to exit"

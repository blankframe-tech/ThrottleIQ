# ThrottleIQ Android Setup Script
# Run as Administrator to set up Android SDK cmdline-tools and build APK
# Usage: powershell -ExecutionPolicy Bypass -File setup-android.ps1

param(
    [switch]$SkipDownload = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ThrottleIQ Android Setup & Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Configuration
$ANDROID_SDK = "C:\Android\sdk"
$CMDLINE_TOOLS_URL = "https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip"
$TEMP_DIR = "$env:TEMP\android-setup"
$PROJECT_ROOT = Split-Path -Parent $PSCommandPath

Write-Host "`n[1/6] Checking directories..." -ForegroundColor Yellow

if (!(Test-Path $ANDROID_SDK)) {
    Write-Host "ERROR: Android SDK not found at $ANDROID_SDK" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $TEMP_DIR)) {
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
}

Write-Host "✓ Android SDK found at $ANDROID_SDK" -ForegroundColor Green

# Download cmdline-tools
Write-Host "`n[2/6] Setting up Android cmdline-tools..." -ForegroundColor Yellow

$CMDLINE_ZIP = "$TEMP_DIR\cmdline-tools.zip"
$CMDLINE_EXTRACT = "$TEMP_DIR\cmdline-tools"

if (!$SkipDownload) {
    Write-Host "Downloading cmdline-tools (~130MB)..."
    try {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $CMDLINE_TOOLS_URL -OutFile $CMDLINE_ZIP -ErrorAction Stop
        Write-Host "✓ Downloaded cmdline-tools" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to download cmdline-tools" -ForegroundColor Red
        Write-Host "URL: $CMDLINE_TOOLS_URL" -ForegroundColor Red
        Write-Host "Try downloading manually and extract to: $ANDROID_SDK\cmdline-tools\latest" -ForegroundColor Yellow
        exit 1
    }
}

# Extract
if (Test-Path $CMDLINE_ZIP) {
    Write-Host "Extracting cmdline-tools..."
    Expand-Archive -Path $CMDLINE_ZIP -DestinationPath $CMDLINE_EXTRACT -Force

    # Move to correct location
    $TOOLS_DIR = "$ANDROID_SDK\cmdline-tools\latest"
    if (Test-Path $TOOLS_DIR) {
        Remove-Item $TOOLS_DIR -Recurse -Force
    }

    New-Item -ItemType Directory -Path "$ANDROID_SDK\cmdline-tools" -Force | Out-Null
    Move-Item -Path "$CMDLINE_EXTRACT\cmdline-tools\*" -Destination "$ANDROID_SDK\cmdline-tools\latest" -Force

    Write-Host "✓ Extracted cmdline-tools" -ForegroundColor Green
}

# Accept licenses
Write-Host "`n[3/6] Accepting Android licenses..." -ForegroundColor Yellow

$SDKMANAGER = "$ANDROID_SDK\cmdline-tools\latest\bin\sdkmanager.bat"

if (Test-Path $SDKMANAGER) {
    # Accept all licenses
    Write-Host "Accepting licenses (this may take a moment)..."

    # Run sdkmanager to accept licenses
    $YES_REPLY = @("yes") * 20 | Out-String
    cmd /c "echo $YES_REPLY | $SDKMANAGER --licenses" 2>&1 | Out-Null

    Write-Host "✓ Licenses accepted" -ForegroundColor Green
} else {
    Write-Host "ERROR: sdkmanager not found at $SDKMANAGER" -ForegroundColor Red
    exit 1
}

# Set environment variables
Write-Host "`n[4/6] Setting environment variables..." -ForegroundColor Yellow

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $ANDROID_SDK, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $ANDROID_SDK, "User")

$env:ANDROID_HOME = $ANDROID_SDK
$env:ANDROID_SDK_ROOT = $ANDROID_SDK

Write-Host "✓ Set ANDROID_HOME=$ANDROID_SDK" -ForegroundColor Green

# Run flutter doctor
Write-Host "`n[5/6] Running flutter doctor..." -ForegroundColor Yellow
flutter doctor -v

# Build APK
Write-Host "`n[6/6] Building release APK..." -ForegroundColor Yellow
Write-Host "This may take 5-15 minutes..." -ForegroundColor Cyan

cd "$PROJECT_ROOT\app"

flutter clean
flutter pub get
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "✓ BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

    $APK = "$(pwd)\build\app\outputs\flutter-app\release\app-release.apk"
    Write-Host "`nAPK location: $APK" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Upload to Google Play Console (internal testing track)" -ForegroundColor White
    Write-Host "2. Or install on test device: adb install -r '$APK'" -ForegroundColor White
} else {
    Write-Host "`nERROR: Build failed" -ForegroundColor Red
    exit 1
}

# Cleanup
Write-Host "`n[Cleanup] Removing temporary files..." -ForegroundColor Yellow
if (Test-Path $TEMP_DIR) {
    Remove-Item $TEMP_DIR -Recurse -Force
}

Write-Host "✓ Setup complete!" -ForegroundColor Green

#Requires -RunAsAdministrator
#==============================================================================
# INSTALL MT5 SILENT - PropFirm EA
# Installs MetaTrader 5 in portable mode without user interaction
#==============================================================================

param(
    [string]$InstallPath = "C:\PropFirmEA\MT5_PropFirm"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $color = switch($Status) {
        "SUCCESS" { "Green" }
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "STEP"    { "Cyan" }
        default   { "White" }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
}

# Header
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   MT5 SILENT INSTALLER - PropFirm EA" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Install path: $InstallPath" -ForegroundColor Gray
Write-Host ""

# Check if already installed
$mt5Exe = Join-Path $InstallPath "terminal64.exe"
if (Test-Path $mt5Exe) {
    Write-Step "MT5 is already installed at $InstallPath" "SUCCESS"
    Write-Step "Configuring portable mode..." "STEP"

    $portableIni = "[Portable]`nDataPath=$InstallPath"
    Set-Content -Path (Join-Path $InstallPath "portable.ini") -Value $portableIni -Encoding ASCII

    Write-Step "Portable mode configured" "SUCCESS"
    Write-Host ""
    Write-Host "Run C:\PropFirmEA\Start_MT5.bat to launch MT5" -ForegroundColor Green
    exit 0
}

# Create directory
Write-Step "Creating installation directory..." "STEP"
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Download MT5
$mt5Url = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
$mt5Installer = "$env:TEMP\mt5setup.exe"

Write-Step "Downloading MetaTrader 5..." "STEP"
Write-Host "   Source: $mt5Url" -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $mt5Url -OutFile $mt5Installer -UseBasicParsing
    Write-Step "Download complete" "SUCCESS"
} catch {
    Write-Step "Download failed: $_" "ERROR"
    exit 1
}

# Install MT5 silently
Write-Step "Installing MetaTrader 5 (silent mode)..." "STEP"
Write-Host "   This may take 2-3 minutes..." -ForegroundColor Gray

# MT5 silent install arguments
$installArgs = "/auto `"$InstallPath`""

try {
    $process = Start-Process -FilePath $mt5Installer -ArgumentList $installArgs -Wait -PassThru

    # Wait a bit for files to be written
    Start-Sleep -Seconds 5

    if (Test-Path $mt5Exe) {
        Write-Step "MT5 installed successfully" "SUCCESS"
    } else {
        # Try alternative method - run installer and wait
        Write-Step "Trying alternative installation method..." "WARN"

        Start-Process -FilePath $mt5Installer -Wait
        Start-Sleep -Seconds 3

        if (-not (Test-Path $mt5Exe)) {
            Write-Step "MT5 not found at expected path after installation" "ERROR"
            Write-Host ""
            Write-Host "Please install manually:" -ForegroundColor Yellow
            Write-Host "1. Run: $mt5Installer" -ForegroundColor White
            Write-Host "2. Click 'Settings' in the installer" -ForegroundColor White
            Write-Host "3. Change path to: $InstallPath" -ForegroundColor White
            Write-Host "4. Complete installation" -ForegroundColor White
            Write-Host "5. Run this script again to configure portable mode" -ForegroundColor White
            exit 1
        }
    }
} catch {
    Write-Step "Installation error: $_" "ERROR"
    exit 1
}

# Clean up installer
Remove-Item $mt5Installer -Force -ErrorAction SilentlyContinue

# Configure portable mode
Write-Step "Configuring portable mode..." "STEP"
$portableIni = "[Portable]`nDataPath=$InstallPath"
Set-Content -Path (Join-Path $InstallPath "portable.ini") -Value $portableIni -Encoding ASCII
Write-Step "Portable mode configured" "SUCCESS"

# Create MQL5 directories
Write-Step "Creating MQL5 directories..." "STEP"
$mql5Dirs = @(
    "MQL5\Experts",
    "MQL5\Include",
    "MQL5\Scripts",
    "MQL5\Presets"
)

foreach ($dir in $mql5Dirs) {
    $fullPath = Join-Path $InstallPath $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }
}
Write-Step "MQL5 directories created" "SUCCESS"

# Deploy EA files
Write-Step "Deploying EA files..." "STEP"
$projectPath = "C:\PropFirmEA\Project"

if (Test-Path $projectPath) {
    $deployCount = 0

    # Deploy MQ5 files to Experts
    $srcExperts = Join-Path $projectPath "EA\MQL5\*.mq5"
    $dstExperts = Join-Path $InstallPath "MQL5\Experts"
    $files = Get-ChildItem -Path $srcExperts -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item $f.FullName -Destination $dstExperts -Force
        Write-Host "   + $($f.Name)" -ForegroundColor Gray
        $deployCount++
    }

    # Deploy SET files to Presets
    $srcPresets = Join-Path $projectPath "config\profiles\*.set"
    $dstPresets = Join-Path $InstallPath "MQL5\Presets"
    $files = Get-ChildItem -Path $srcPresets -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item $f.FullName -Destination $dstPresets -Force
        Write-Host "   + $($f.Name)" -ForegroundColor Gray
        $deployCount++
    }

    # Deploy MQH files to Include
    $srcInclude = Join-Path $projectPath "backtests\*.mqh"
    $dstInclude = Join-Path $InstallPath "MQL5\Include"
    $files = Get-ChildItem -Path $srcInclude -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Copy-Item $f.FullName -Destination $dstInclude -Force
        Write-Host "   + $($f.Name)" -ForegroundColor Gray
        $deployCount++
    }

    Write-Step "$deployCount files deployed" "SUCCESS"
} else {
    Write-Step "Project folder not found, skipping EA deployment" "WARN"
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "MT5 installed at: $InstallPath" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Run: C:\PropFirmEA\Start_MT5.bat" -ForegroundColor White
Write-Host "2. Connect your broker account in MT5" -ForegroundColor White
Write-Host "3. Go to Navigator > Expert Advisors" -ForegroundColor White
Write-Host "4. Right-click PropFirm_SMC_EA_v1 > Compile" -ForegroundColor White
Write-Host "5. Drag EA onto a chart (EURUSD M15)" -ForegroundColor White
Write-Host ""

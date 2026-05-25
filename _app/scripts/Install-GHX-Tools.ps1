<#
Install-GHX-Tools.ps1

GHX Replay Toolkit dependency installer/checker.

Installs/checks:
- Python
- customtkinter
- FFmpeg / FFprobe
- HandBrakeCLI
- rife-ncnn-vulkan

Installs portable video tools into:
C:\ReplayVault\_app\bin

Python is installed via winget when missing.
customtkinter is installed via python -m pip.
#>

$ErrorActionPreference = "Stop"

$ScriptRoot = $PSScriptRoot
$AppPath    = Split-Path $ScriptRoot -Parent
$BasePath   = Split-Path $AppPath -Parent

$BinPath      = Join-Path $AppPath "bin"
$DownloadPath = Join-Path $AppPath "_downloads"

$FFmpegPath    = Join-Path $BinPath "ffmpeg"
$HandBrakePath = Join-Path $BinPath "HandBrakeCLI"
$RifePath      = Join-Path $BinPath "rife-ncnn-vulkan"

$FFmpegExe    = Join-Path $FFmpegPath "bin\ffmpeg.exe"
$FFprobeExe   = Join-Path $FFmpegPath "bin\ffprobe.exe"
$HandBrakeExe = Join-Path $HandBrakePath "HandBrakeCLI.exe"
$RifeExe      = Join-Path $RifePath "rife-ncnn-vulkan.exe"

function Ensure-Folder {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Step {
    param ([string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param ([string]$Message)

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param ([string]$Message)

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param ([string]$Message)

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Get-CommandPath {
    param ([string]$Command)

    $Result = Get-Command $Command -ErrorAction SilentlyContinue

    if ($Result) {
        return $Result.Source
    }

    return $null
}

function Test-Winget {
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

function Get-PythonCommand {
    $Python = Get-Command python -ErrorAction SilentlyContinue

    if ($Python) {
        try {
            $VersionOutput = & python --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $VersionOutput -match "Python") {
                return "python"
            }
        }
        catch {}
    }

    $Py = Get-Command py -ErrorAction SilentlyContinue

    if ($Py) {
        try {
            $VersionOutput = & py -3 --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $VersionOutput -match "Python") {
                return "py -3"
            }
        }
        catch {}
    }

    return $null
}

function Invoke-Python {
    param (
        [string]$PythonCommand,
        [string[]]$Arguments
    )

    if ($PythonCommand -eq "python") {
        & python @Arguments
        return $LASTEXITCODE
    }

    if ($PythonCommand -eq "py -3") {
        & py -3 @Arguments
        return $LASTEXITCODE
    }

    throw "Unsupported Python command: $PythonCommand"
}

function Install-Python {
    Write-Step "Checking Python"

    $PythonCommand = Get-PythonCommand

    if ($PythonCommand) {
        $VersionOutput = if ($PythonCommand -eq "python") { & python --version } else { & py -3 --version }
        Write-Ok "Python found: $VersionOutput"
        return $PythonCommand
    }

    Write-Warn "Python was not found."

    if (!(Test-Winget)) {
        Write-Fail "winget was not found. Install Python manually from python.org or install App Installer from Microsoft Store."
        throw "winget missing and Python missing."
    }

    Write-Host ""
    Write-Host "Python is required for the GHX UI." -ForegroundColor Yellow
    Write-Host "The installer will now try to install Python using winget." -ForegroundColor Yellow
    Write-Host "You may need to accept a UAC/admin prompt or installer prompt." -ForegroundColor Yellow
    Write-Host ""

    $Answer = Read-Host "Install Python now? Y/N"

    if ($Answer.ToUpper() -ne "Y") {
        throw "Python install declined by user."
    }

    $PythonPackages = @(
        "Python.Python.3.14",
        "Python.Python.3.13",
        "Python.Python.3.12"
    )

    $Installed = $false

    foreach ($Package in $PythonPackages) {
        Write-Step "Trying winget install $Package"

        winget install -e --id $Package --source winget --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            $Installed = $true
            break
        }

        Write-Warn "Could not install $Package. Trying next option..."
    }

    if (!$Installed) {
        throw "Python installation failed using winget."
    }

    Write-Host ""
    Write-Warn "Python was installed. If Python is still not detected, close this window and run INSTALL.bat again."
    Write-Warn "This is normal because PATH may only refresh in a new terminal."

    $PythonCommand = Get-PythonCommand

    if (!$PythonCommand) {
        return $null
    }

    return $PythonCommand
}

function Install-CustomTkinter {
    param ([string]$PythonCommand)

    Write-Step "Checking customtkinter"

    if (!$PythonCommand) {
        Write-Warn "Python command not available in this session. Rerun installer after reopening the terminal."
        return
    }

    Invoke-Python -PythonCommand $PythonCommand -Arguments @("-c", "import customtkinter; print('customtkinter ok')") | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Ok "customtkinter already installed."
        return
    }

    Write-Warn "customtkinter not found. Installing with pip..."

    Invoke-Python -PythonCommand $PythonCommand -Arguments @("-m", "pip", "install", "--upgrade", "pip")
    Invoke-Python -PythonCommand $PythonCommand -Arguments @("-m", "pip", "install", "customtkinter")

    Invoke-Python -PythonCommand $PythonCommand -Arguments @("-c", "import customtkinter; print('customtkinter ok')") | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "customtkinter install failed."
    }

    Write-Ok "customtkinter installed."
}

function Download-File {
    param (
        [string]$Url,
        [string]$OutputPath
    )

    Write-Host "Downloading:" -ForegroundColor Cyan
    Write-Host "  $Url" -ForegroundColor Gray
    Write-Host "To:" -ForegroundColor Cyan
    Write-Host "  $OutputPath" -ForegroundColor Gray

    Invoke-WebRequest -Uri $Url -OutFile $OutputPath
}

function Expand-ZipClean {
    param (
        [string]$ZipPath,
        [string]$Destination,
        [string]$ExpectedExe
    )

    $TempExtract = Join-Path $DownloadPath ("extract_" + [guid]::NewGuid().ToString())

    Ensure-Folder $TempExtract

    Write-Host "Extracting $ZipPath..." -ForegroundColor Yellow
    Expand-Archive -Path $ZipPath -DestinationPath $TempExtract -Force

    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force
    }

    Ensure-Folder $Destination

    $Exe = Get-ChildItem -Path $TempExtract -Filter $ExpectedExe -Recurse -File | Select-Object -First 1

    if (!$Exe) {
        throw "Could not find $ExpectedExe inside $ZipPath"
    }

    $RootToCopy = $Exe.Directory.FullName

    # For FFmpeg, ffmpeg.exe lives inside a bin folder. We want the parent folder that contains bin.
    if ($ExpectedExe -eq "ffmpeg.exe" -and (Split-Path $RootToCopy -Leaf) -eq "bin") {
        $RootToCopy = Split-Path $RootToCopy -Parent
    }

    Write-Host "Installing to $Destination..." -ForegroundColor Yellow
    Copy-Item -Path (Join-Path $RootToCopy "*") -Destination $Destination -Recurse -Force

    Remove-Item $TempExtract -Recurse -Force
}

function Install-FFmpeg {
    Write-Step "Checking FFmpeg"

    if ((Test-Path $FFmpegExe) -and (Test-Path $FFprobeExe)) {
        Write-Ok "FFmpeg already installed."
        return
    }

    $ZipPath = Join-Path $DownloadPath "ffmpeg-release-essentials.zip"
    $Url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

    Download-File -Url $Url -OutputPath $ZipPath
    Expand-ZipClean -ZipPath $ZipPath -Destination $FFmpegPath -ExpectedExe "ffmpeg.exe"

    if (!(Test-Path $FFmpegExe)) {
        throw "FFmpeg install failed. Missing $FFmpegExe"
    }

    if (!(Test-Path $FFprobeExe)) {
        throw "FFprobe install failed. Missing $FFprobeExe"
    }

    Write-Ok "FFmpeg installed."
}

function Install-HandBrakeCLI {
    Write-Step "Checking HandBrakeCLI"

    if (Test-Path $HandBrakeExe) {
        Write-Ok "HandBrakeCLI already installed."
        return
    }

    $Version = "1.11.1"
    $ZipPath = Join-Path $DownloadPath "HandBrakeCLI-$Version-win-x86_64.zip"
    $Url = "https://github.com/HandBrake/HandBrake/releases/download/$Version/HandBrakeCLI-$Version-win-x86_64.zip"

    Download-File -Url $Url -OutputPath $ZipPath
    Expand-ZipClean -ZipPath $ZipPath -Destination $HandBrakePath -ExpectedExe "HandBrakeCLI.exe"

    if (!(Test-Path $HandBrakeExe)) {
        throw "HandBrakeCLI install failed. Missing $HandBrakeExe"
    }

    Write-Ok "HandBrakeCLI installed."
}

function Install-RIFE {
    Write-Step "Checking rife-ncnn-vulkan"

    if (Test-Path $RifeExe) {
        Write-Ok "rife-ncnn-vulkan already installed."
        return
    }

    $Release = "20221029"
    $ZipPath = Join-Path $DownloadPath "rife-ncnn-vulkan-$Release-windows.zip"
    $Url = "https://github.com/nihui/rife-ncnn-vulkan/releases/download/$Release/rife-ncnn-vulkan-$Release-windows.zip"

    Download-File -Url $Url -OutputPath $ZipPath
    Expand-ZipClean -ZipPath $ZipPath -Destination $RifePath -ExpectedExe "rife-ncnn-vulkan.exe"

    if (!(Test-Path $RifeExe)) {
        throw "RIFE install failed. Missing $RifeExe"
    }

    Write-Ok "rife-ncnn-vulkan installed."
}

function Test-Tools {
    Write-Step "Final tool check"

    if (Test-Path $FFmpegExe) {
        & $FFmpegExe -version | Select-Object -First 1
    }
    else {
        Write-Fail "Missing FFmpeg"
    }

    if (Test-Path $FFprobeExe) {
        & $FFprobeExe -version | Select-Object -First 1
    }
    else {
        Write-Fail "Missing FFprobe"
    }

    if (Test-Path $HandBrakeExe) {
        & $HandBrakeExe --version
    }
    else {
        Write-Fail "Missing HandBrakeCLI"
    }

    if (Test-Path $RifeExe) {
        & $RifeExe -h | Select-Object -First 5
    }
    else {
        Write-Fail "Missing RIFE"
    }
}

Ensure-Folder $BinPath
Ensure-Folder $DownloadPath

Write-Host ""
Write-Host "GHX Replay Toolkit dependency installer" -ForegroundColor Cyan
Write-Host "App path: $AppPath" -ForegroundColor Gray
Write-Host ""

$PythonCommand = Install-Python
Install-CustomTkinter -PythonCommand $PythonCommand

Install-FFmpeg
Install-HandBrakeCLI
Install-RIFE

Test-Tools

Write-Host ""
Write-Host "Install/check complete." -ForegroundColor Green
Write-Host "You can now run GHX-UI.vbs or START.bat."
Write-Host ""
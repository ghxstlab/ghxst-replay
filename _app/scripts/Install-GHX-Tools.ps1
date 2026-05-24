<#
Install-GHX-Tools.ps1

Downloads and installs portable tool dependencies into:

C:\ReplayVault\_app\bin

Tools:
- FFmpeg / FFprobe
- HandBrakeCLI
- rife-ncnn-vulkan

Run from:
C:\ReplayVault\_app\launchers\Install-GHX-Tools.bat
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
    if ((Test-Path $FFmpegExe) -and (Test-Path $FFprobeExe)) {
        Write-Host "FFmpeg already installed." -ForegroundColor Green
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

    Write-Host "FFmpeg installed." -ForegroundColor Green
}

function Install-HandBrakeCLI {
    if (Test-Path $HandBrakeExe) {
        Write-Host "HandBrakeCLI already installed." -ForegroundColor Green
        return
    }

    # Update this manually when HandBrake releases a new CLI version.
    # Current official command-line download page showed 1.11.1 at time of writing.
    $Version = "1.11.1"
    $ZipPath = Join-Path $DownloadPath "HandBrakeCLI-$Version-win-x86_64.zip"
    $Url = "https://github.com/HandBrake/HandBrake/releases/download/$Version/HandBrakeCLI-$Version-win-x86_64.zip"

    Download-File -Url $Url -OutputPath $ZipPath
    Expand-ZipClean -ZipPath $ZipPath -Destination $HandBrakePath -ExpectedExe "HandBrakeCLI.exe"

    if (!(Test-Path $HandBrakeExe)) {
        throw "HandBrakeCLI install failed. Missing $HandBrakeExe"
    }

    Write-Host "HandBrakeCLI installed." -ForegroundColor Green
}

function Install-RIFE {
    if (Test-Path $RifeExe) {
        Write-Host "rife-ncnn-vulkan already installed." -ForegroundColor Green
        return
    }

    # This release is commonly used and stable.
    # You can update this later if you test a newer RIFE release.
    $Release = "20221029"
    $ZipPath = Join-Path $DownloadPath "rife-ncnn-vulkan-$Release-windows.zip"
    $Url = "https://github.com/nihui/rife-ncnn-vulkan/releases/download/$Release/rife-ncnn-vulkan-$Release-windows.zip"

    Download-File -Url $Url -OutputPath $ZipPath
    Expand-ZipClean -ZipPath $ZipPath -Destination $RifePath -ExpectedExe "rife-ncnn-vulkan.exe"

    if (!(Test-Path $RifeExe)) {
        throw "RIFE install failed. Missing $RifeExe"
    }

    Write-Host "rife-ncnn-vulkan installed." -ForegroundColor Green
}

function Test-Tools {
    Write-Host ""
    Write-Host "Testing installed tools..." -ForegroundColor Cyan

    & $FFmpegExe -version | Select-Object -First 1
    & $FFprobeExe -version | Select-Object -First 1
    & $HandBrakeExe --version
    & $RifeExe -h | Select-Object -First 5

    Write-Host ""
    Write-Host "All tool checks completed." -ForegroundColor Green
}

Ensure-Folder $BinPath
Ensure-Folder $DownloadPath

Write-Host ""
Write-Host "GHX Replay Toolkit dependency installer" -ForegroundColor Cyan
Write-Host "App path: $AppPath" -ForegroundColor Gray
Write-Host ""

Install-FFmpeg
Install-HandBrakeCLI
Install-RIFE
Test-Tools

Write-Host ""
Write-Host "Install complete." -ForegroundColor Green
Write-Host "You can now run GHX-Replay-Toolkit.bat"
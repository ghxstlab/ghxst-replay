<#
Run-GHX-Replay-Toolkit.ps1

Main GHX Replay Toolkit launcher.

Controls:
- Compression profiles
- RIFE 120FPS enhancement
- Folder shortcuts
- Logs
#>

# =========================
# App paths
# =========================

$ScriptRoot = $PSScriptRoot
$AppPath    = Split-Path $ScriptRoot -Parent
$BasePath   = Split-Path $AppPath -Parent

$ReplayPath            = Join-Path $BasePath "00_REPLAY"

$CompressRootPath      = Join-Path $BasePath "01_COMPRESS_INGEST"
$CompressInputPath     = Join-Path $CompressRootPath "input"
$CompressInProgressPath = Join-Path $CompressRootPath "inprogress"
$CompressCompletePath  = Join-Path $CompressRootPath "complete"

$CompressedPath        = Join-Path $BasePath "03_COMPRESSED"
$SortedPath            = Join-Path $BasePath "04_SORTED"

$RifeIngestPath        = Join-Path $BasePath "05_RIFE_INGEST"
$RifeOutputPath        = Join-Path $BasePath "07_RIFE_OUTPUT"

$LogPath               = Join-Path $BasePath "logs"

$CoreScript            = Join-Path $ScriptRoot "Replay-Condenser-Core.ps1"
$NormalCPU             = Join-Path $ScriptRoot "Replay-Condenser-Normal-CPU.ps1"
$NormalNVENC           = Join-Path $ScriptRoot "Replay-Condenser-Normal-NVENC.ps1"
$AggressiveNVENC       = Join-Path $ScriptRoot "Replay-Condenser-Aggressive-NVENC.ps1"
$RifeEnhancer          = Join-Path $ScriptRoot "Replay-Enhance-RIFE-120.ps1"

# =========================
# Helper functions
# =========================

function Ensure-Folder {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-PowerShellExecutable {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        return "pwsh"
    }

    return "powershell"
}

function Get-FileCount {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        return 0
    }

    $Files = Get-ChildItem -Path $Path -File -Recurse -Include *.mp4, *.mkv, *.mov -ErrorAction SilentlyContinue
    return @($Files).Count
}

function Show-Header {
    $InputCount      = Get-FileCount -Path $CompressInputPath
    $InProgressCount = Get-FileCount -Path $CompressInProgressPath
    $CompleteCount   = Get-FileCount -Path $CompressCompletePath
    $RifeInputCount  = Get-FileCount -Path $RifeIngestPath

    Clear-Host
    Write-Host ""
    Write-Host "  ██████╗ ██╗  ██╗██╗  ██╗    ██████╗ ███████╗██████╗ ██╗      █████╗ ██╗   ██╗" -ForegroundColor Cyan
    Write-Host " ██╔════╝ ██║  ██║╚██╗██╔╝    ██╔══██╗██╔════╝██╔══██╗██║     ██╔══██╗╚██╗ ██╔╝" -ForegroundColor Cyan
    Write-Host " ██║  ███╗███████║ ╚███╔╝     ██████╔╝█████╗  ██████╔╝██║     ███████║ ╚████╔╝ " -ForegroundColor Cyan
    Write-Host " ██║   ██║██╔══██║ ██╔██╗     ██╔══██╗██╔══╝  ██╔═══╝ ██║     ██╔══██║  ╚██╔╝  " -ForegroundColor DarkCyan
    Write-Host " ╚██████╔╝██║  ██║██╔╝ ██╗    ██║  ██║███████╗██║     ███████╗██║  ██║   ██║   " -ForegroundColor DarkCyan
    Write-Host "  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   " -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  GHX Replay Toolkit" -ForegroundColor White
    Write-Host ""
    Write-Host "  Raw OBS          : $ReplayPath" -ForegroundColor DarkGray
    Write-Host "  Compress Input   : $CompressInputPath" -ForegroundColor Gray
    Write-Host "  Compressed Out   : $CompressedPath" -ForegroundColor Gray
    Write-Host "  RIFE Input       : $RifeIngestPath" -ForegroundColor Gray
    Write-Host "  RIFE Output      : $RifeOutputPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Queue Status" -ForegroundColor Cyan
    Write-Host "  Compress Input   : $InputCount file(s)" -ForegroundColor White
    Write-Host "  In Progress      : $InProgressCount file(s)" -ForegroundColor Yellow
    Write-Host "  Complete Sources : $CompleteCount file(s)" -ForegroundColor Green
    Write-Host "  RIFE Input       : $RifeInputCount file(s)" -ForegroundColor Magenta
    Write-Host ""
}

function Run-Script {
    param (
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$ExtraArgs = @()
    )

    if (!(Test-Path $ScriptPath)) {
        Write-Host ""
        Write-Host "Missing script: $ScriptPath" -ForegroundColor Red
        Pause
        return
    }

    Write-Host ""
    Write-Host "Running: $Name" -ForegroundColor Cyan
    Write-Host ""

    $PowerShellExe = Get-PowerShellExecutable

    & $PowerShellExe -ExecutionPolicy Bypass -File $ScriptPath @ExtraArgs

    Write-Host ""
    Write-Host "Finished: $Name" -ForegroundColor Green
}

function Open-Folder {
    param ([string]$Path)

    Ensure-Folder -Path $Path
    explorer $Path
}

function Show-QueueStatus {
    Clear-Host
    Write-Host ""
    Write-Host "GHX Replay Toolkit - Queue Status" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Compression Queue" -ForegroundColor Cyan
    Write-Host "Input      : $(Get-FileCount -Path $CompressInputPath) file(s)" -ForegroundColor White
    Write-Host "InProgress : $(Get-FileCount -Path $CompressInProgressPath) file(s)" -ForegroundColor Yellow
    Write-Host "Complete   : $(Get-FileCount -Path $CompressCompletePath) file(s)" -ForegroundColor Green
    Write-Host ""

    Write-Host "RIFE Queue" -ForegroundColor Magenta
    Write-Host "Input      : $(Get-FileCount -Path $RifeIngestPath) file(s)" -ForegroundColor White
    Write-Host "Output     : $(Get-FileCount -Path $RifeOutputPath) file(s)" -ForegroundColor Green
    Write-Host ""

    Pause
}

# =========================
# Ensure folders exist
# =========================

$RequiredFolders = @(
    $ReplayPath,
    $CompressRootPath,
    $CompressInputPath,
    $CompressInProgressPath,
    $CompressCompletePath,
    $CompressedPath,
    $SortedPath,
    $RifeIngestPath,
    $RifeOutputPath,
    $LogPath
)

foreach ($Folder in $RequiredFolders) {
    Ensure-Folder -Path $Folder
}

# =========================
# Main menu
# =========================

do {
    Show-Header

    Write-Host "  Compression" -ForegroundColor Cyan
    Write-Host "  1. Normal CPU              Best quality/size, slower" -ForegroundColor White
    Write-Host "  2. Normal NVENC            Fast, decent size" -ForegroundColor White
    Write-Host "  3. Aggressive NVENC        Fast, much smaller, more quality loss" -ForegroundColor White
    Write-Host "  4. Run all compression     Side-by-side testing" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "  RIFE Enhancement" -ForegroundColor Magenta
    Write-Host "  5. Run RIFE 120FPS         Smooth 120fps enhancement" -ForegroundColor White
    Write-Host ""

    Write-Host "  Status" -ForegroundColor Cyan
    Write-Host "  6. Show queue status" -ForegroundColor White
    Write-Host ""

    Write-Host "  Folders" -ForegroundColor DarkCyan
    Write-Host "  7. Open RAW OBS folder" -ForegroundColor Gray
    Write-Host "  8. Open COMPRESS input folder" -ForegroundColor Gray
    Write-Host "  9. Open COMPRESS inprogress folder" -ForegroundColor Gray
    Write-Host "  10. Open COMPRESS complete folder" -ForegroundColor Gray
    Write-Host "  11. Open COMPRESSED output folder" -ForegroundColor Gray
    Write-Host "  12. Open RIFE input folder" -ForegroundColor Gray
    Write-Host "  13. Open RIFE output folder" -ForegroundColor Gray
    Write-Host "  14. Open logs folder" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Q. Quit" -ForegroundColor DarkGray
    Write-Host ""

    $Choice = Read-Host "Select an option"

    switch ($Choice.ToUpper()) {
        "1" {
            Run-Script -Name "Normal CPU Compression" -ScriptPath $NormalCPU
            Pause
        }

        "2" {
            Run-Script -Name "Normal NVENC Compression" -ScriptPath $NormalNVENC
            Pause
        }

        "3" {
            Run-Script -Name "Aggressive NVENC Compression" -ScriptPath $AggressiveNVENC
            Pause
        }

        "4" {
            Run-Script -Name "Normal CPU Compression" -ScriptPath $CoreScript -ExtraArgs @("-Profile", "Normal-CPU", "-CompletionMode", "AllProfiles")
            Run-Script -Name "Normal NVENC Compression" -ScriptPath $CoreScript -ExtraArgs @("-Profile", "Normal-NVENC", "-CompletionMode", "AllProfiles")
            Run-Script -Name "Aggressive NVENC Compression" -ScriptPath $CoreScript -ExtraArgs @("-Profile", "Aggressive-NVENC", "-CompletionMode", "AllProfiles")
            Pause
        }

        "5" {
            Run-Script -Name "RIFE 120FPS Enhancement" -ScriptPath $RifeEnhancer
            Pause
        }

        "6" {
            Show-QueueStatus
        }

        "7" {
            Open-Folder -Path $ReplayPath
        }

        "8" {
            Open-Folder -Path $CompressInputPath
        }

        "9" {
            Open-Folder -Path $CompressInProgressPath
        }

        "10" {
            Open-Folder -Path $CompressCompletePath
        }

        "11" {
            Open-Folder -Path $CompressedPath
        }

        "12" {
            Open-Folder -Path $RifeIngestPath
        }

        "13" {
            Open-Folder -Path $RifeOutputPath
        }

        "14" {
            Open-Folder -Path $LogPath
        }

        "Q" {
            break
        }

        default {
            Write-Host ""
            Write-Host "Invalid option." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
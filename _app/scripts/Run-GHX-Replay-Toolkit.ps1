<#
Run-GHX-Replay-Toolkit.ps1

Main GHX Replay Toolkit launcher.
Controls:
- Compression profiles
- RIFE 120FPS enhancement
- Folder shortcuts
- Logs
#>

$ScriptRoot = $PSScriptRoot
$AppPath    = Split-Path $ScriptRoot -Parent
$BasePath   = Split-Path $AppPath -Parent

$ReplayPath          = Join-Path $BasePath "00_REPLAY"
$CompressIngestPath  = Join-Path $BasePath "01_COMPRESS_INGEST"
$CompressedPath      = Join-Path $BasePath "03_COMPRESSED"
$SortedPath          = Join-Path $BasePath "04_SORTED"
$RifeIngestPath      = Join-Path $BasePath "05_RIFE_INGEST"
$RifeOutputPath      = Join-Path $BasePath "07_RIFE_OUTPUT"
$LogPath             = Join-Path $BasePath "logs"

$NormalCPU           = Join-Path $ScriptRoot "Replay-Condenser-Normal-CPU.ps1"
$NormalNVENC         = Join-Path $ScriptRoot "Replay-Condenser-Normal-NVENC.ps1"
$AggressiveNVENC     = Join-Path $ScriptRoot "Replay-Condenser-Aggressive-NVENC.ps1"
$RifeEnhancer        = Join-Path $ScriptRoot "Replay-Enhance-RIFE-120.ps1"

function Show-Header {
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
    Write-Host "  Raw OBS      : $ReplayPath" -ForegroundColor DarkGray
    Write-Host "  Compress In : $CompressIngestPath" -ForegroundColor Gray
    Write-Host "  RIFE In     : $RifeIngestPath" -ForegroundColor Gray
    Write-Host ""
}

function Run-Script {
    param (
        [string]$Name,
        [string]$ScriptPath
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

    & pwsh -ExecutionPolicy Bypass -File $ScriptPath

    Write-Host ""
    Write-Host "Finished: $Name" -ForegroundColor Green
}

function Open-Folder {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    explorer $Path
}

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

    Write-Host "  Folders" -ForegroundColor DarkCyan
    Write-Host "  6. Open RAW OBS folder" -ForegroundColor Gray
    Write-Host "  7. Open COMPRESS_INGEST folder" -ForegroundColor Gray
    Write-Host "  8. Open COMPRESSED output folder" -ForegroundColor Gray
    Write-Host "  9. Open RIFE_INGEST folder" -ForegroundColor Gray
    Write-Host "  10. Open RIFE_OUTPUT folder" -ForegroundColor Gray
    Write-Host "  11. Open logs folder" -ForegroundColor Gray
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
            Run-Script -Name "Normal CPU Compression" -ScriptPath $NormalCPU
            Run-Script -Name "Normal NVENC Compression" -ScriptPath $NormalNVENC
            Run-Script -Name "Aggressive NVENC Compression" -ScriptPath $AggressiveNVENC
            Pause
        }

        "5" {
            Run-Script -Name "RIFE 120FPS Enhancement" -ScriptPath $RifeEnhancer
            Pause
        }

        "6" {
            Open-Folder -Path $ReplayPath
        }

        "7" {
            Open-Folder -Path $CompressIngestPath
        }

        "8" {
            Open-Folder -Path $CompressedPath
        }

        "9" {
            Open-Folder -Path $RifeIngestPath
        }

        "10" {
            Open-Folder -Path $RifeOutputPath
        }

        "11" {
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
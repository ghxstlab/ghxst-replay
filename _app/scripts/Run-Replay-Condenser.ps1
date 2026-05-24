<#
Run-Replay-Condenser.ps1

GHX Replay Condenser menu launcher.
Designed for the self-contained C:\ReplayVault\_app layout.
#>

$ScriptRoot = $PSScriptRoot
$AppPath    = Split-Path $ScriptRoot -Parent
$BasePath   = Split-Path $AppPath -Parent

$CompressedPath = Join-Path $BasePath "03_COMPRESSED"
$IngestPath     = Join-Path $BasePath "01_COMPRESS_INGEST"
$ReplayPath     = Join-Path $BasePath "00_REPLAY"
$LogPath        = Join-Path $BasePath "logs"

$NormalCPU       = Join-Path $ScriptRoot "Replay-Condenser-Normal-CPU.ps1"
$NormalNVENC     = Join-Path $ScriptRoot "Replay-Condenser-Normal-NVENC.ps1"
$AggressiveNVENC = Join-Path $ScriptRoot "Replay-Condenser-Aggressive-NVENC.ps1"

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
    Write-Host "  GHX Replay Condenser" -ForegroundColor White
    Write-Host "  Raw OBS : $ReplayPath" -ForegroundColor DarkGray
    Write-Host "  Input   : $IngestPath" -ForegroundColor Gray
    Write-Host "  Output  : $CompressedPath" -ForegroundColor Gray
    Write-Host ""
}

function Run-Profile {
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
    Write-Host "Running profile: $Name" -ForegroundColor Cyan
    Write-Host ""

    & pwsh -ExecutionPolicy Bypass -File $ScriptPath

    Write-Host ""
    Write-Host "Finished profile: $Name" -ForegroundColor Green
}

do {
    Show-Header

    Write-Host "  1. Normal CPU              Best quality/size, slower" -ForegroundColor White
    Write-Host "  2. Normal NVENC            Fast, decent size" -ForegroundColor White
    Write-Host "  3. Aggressive NVENC        Fast, much smaller, more quality loss" -ForegroundColor White
    Write-Host "  4. Run all 3 profiles      Best for side-by-side testing" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  5. Open RAW OBS folder" -ForegroundColor Gray
    Write-Host "  6. Open COMPRESS_INGEST folder" -ForegroundColor Gray
    Write-Host "  7. Open COMPRESSED output folder" -ForegroundColor Gray
    Write-Host "  8. Open logs folder" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Q. Quit" -ForegroundColor DarkGray
    Write-Host ""

    $Choice = Read-Host "Select an option"

    switch ($Choice.ToUpper()) {
        "1" {
            Run-Profile -Name "Normal CPU" -ScriptPath $NormalCPU
            Pause
        }

        "2" {
            Run-Profile -Name "Normal NVENC" -ScriptPath $NormalNVENC
            Pause
        }

        "3" {
            Run-Profile -Name "Aggressive NVENC" -ScriptPath $AggressiveNVENC
            Pause
        }

        "4" {
            Run-Profile -Name "Normal CPU" -ScriptPath $NormalCPU
            Run-Profile -Name "Normal NVENC" -ScriptPath $NormalNVENC
            Run-Profile -Name "Aggressive NVENC" -ScriptPath $AggressiveNVENC
            Pause
        }

        "5" {
            explorer $ReplayPath
        }

        "6" {
            explorer $IngestPath
        }

        "7" {
            explorer $CompressedPath
        }

        "8" {
            explorer $LogPath
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
<#
GHX Replay Condenser Core

Input:
C:\ReplayVault\01_COMPRESS_INGEST

Processing:
C:\ReplayVault\02_COMPRESS_PROCESSING

Output:
C:\ReplayVault\03_COMPRESSED\YYYY-MM
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Normal-CPU", "Normal-NVENC", "Aggressive-NVENC")]
    [string]$Profile
)

# =========================
# App paths
# =========================

$ScriptRoot = $PSScriptRoot
$AppPath    = Split-Path $ScriptRoot -Parent
$BasePath   = Split-Path $AppPath -Parent

$HandBrakeCLI = Join-Path $AppPath "bin\HandBrakeCLI\HandBrakeCLI.exe"

# =========================
# Global settings
# =========================

$DeleteOriginalAfterSuccess = $false
$MinimumFileAgeSeconds = 45
$Extensions = @("*.mp4", "*.mkv", "*.mov")

$TargetWidth  = 2560
$TargetHeight = 1440

# =========================
# Profile settings
# =========================

switch ($Profile) {
    "Normal-CPU" {
        $ProfileLabel        = "Normal CPU"
        $OutputProfileFolder = "Normal-CPU"
        $Encoder             = "x265"
        $Quality             = 24
        $EncoderPreset       = "slower"
        $TargetFPS           = 60
        $FrameMode           = "pfr"
        $AudioBitrate        = 160
    }

    "Normal-NVENC" {
        $ProfileLabel        = "Normal NVENC"
        $OutputProfileFolder = "Normal-NVENC"
        $Encoder             = "nvenc_h265"
        $Quality             = 28
        $EncoderPreset       = "hq"
        $TargetFPS           = 60
        $FrameMode           = "pfr"
        $AudioBitrate        = 160
    }

    "Aggressive-NVENC" {
        $ProfileLabel        = "Aggressive NVENC"
        $OutputProfileFolder = "Aggressive-NVENC"
        $Encoder             = "nvenc_h265"
        $Quality             = 34
        $EncoderPreset       = "hq"
        $TargetFPS           = 60
        $FrameMode           = "pfr"
        $AudioBitrate        = 128
    }
}

# =========================
# Folder paths
# =========================

$ReplayPath     = Join-Path $BasePath "00_REPLAY"
$IngestPath     = Join-Path $BasePath "01_COMPRESS_INGEST"
$ProcessingPath = Join-Path $BasePath "02_COMPRESS_PROCESSING"
$CompressedPath = Join-Path $BasePath "03_COMPRESSED"
$SortedPath     = Join-Path $BasePath "04_SORTED"
$LogPath        = Join-Path $BasePath "logs"
$LogFile        = Join-Path $LogPath "replay-condenser.log"

# =========================
# Helper functions
# =========================

function Ensure-Folder {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-Log {
    param ([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "$Timestamp - $Message"
    $Line | Tee-Object -FilePath $LogFile -Append
}

function Get-SafeName {
    param ([string]$Name)

    $NameOnly = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $SafeName = $NameOnly -replace '[^\w\-.]+', '_'
    return $SafeName.Trim("_")
}

function Get-ClipDateInfo {
    param ([System.IO.FileInfo]$File)

    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)

    if ($BaseName -match "Replay (?<date>\d{4}-\d{2}-\d{2}) (?<time>\d{2}-\d{2}-\d{2})") {
        $DatePart  = $Matches["date"]
        $TimePart  = $Matches["time"]
        $MonthPart = $DatePart.Substring(0, 7)
        $CleanName = "Replay_$DatePart`_$TimePart"
    }
    else {
        $DatePart  = $File.LastWriteTime.ToString("yyyy-MM-dd")
        $TimePart  = $File.LastWriteTime.ToString("HH-mm-ss")
        $MonthPart = $File.LastWriteTime.ToString("yyyy-MM")
        $CleanName = Get-SafeName -Name $File.Name
    }

    return [PSCustomObject]@{
        DatePart  = $DatePart
        TimePart  = $TimePart
        MonthPart = $MonthPart
        CleanName = $CleanName
    }
}

function Get-UniquePath {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        return $Path
    }

    $Directory = [System.IO.Path]::GetDirectoryName($Path)
    $NameOnly  = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $Extension = [System.IO.Path]::GetExtension($Path)

    $Counter = 2
    do {
        $NewPath = Join-Path $Directory "$NameOnly`_$Counter$Extension"
        $Counter++
    } while (Test-Path $NewPath)

    return $NewPath
}

# =========================
# Startup checks
# =========================

$RequiredFolders = @(
    $ReplayPath,
    $IngestPath,
    $ProcessingPath,
    $CompressedPath,
    $SortedPath,
    $LogPath
)

foreach ($Folder in $RequiredFolders) {
    Ensure-Folder $Folder
}

Write-Log "========================================"
Write-Log "GHX Replay Condenser started. Profile=$ProfileLabel Encoder=$Encoder Quality=$Quality Preset=$EncoderPreset FPS=$TargetFPS FrameMode=$FrameMode"

if (!(Test-Path $HandBrakeCLI)) {
    Write-Log "ERROR: HandBrakeCLI not found at $HandBrakeCLI"
    Write-Host "HandBrakeCLI not found at: $HandBrakeCLI" -ForegroundColor Red
    exit 1
}

$Files = foreach ($Ext in $Extensions) {
    Get-ChildItem -Path $IngestPath -Filter $Ext -File -ErrorAction SilentlyContinue
}

if (!$Files -or $Files.Count -eq 0) {
    Write-Log "No clips found in compress ingest folder."
    Write-Host "No clips found in $IngestPath"
    Write-Host "Move a clip from 00_REPLAY to 01_COMPRESS_INGEST, then run again."
    exit 0
}

Write-Log "Found $($Files.Count) clip(s)."

foreach ($File in $Files) {
    $TempInput = $null
    $OutputFile = $null

    try {
        Write-Log "Checking clip: $($File.Name)"

        $AgeSeconds = ((Get-Date) - $File.LastWriteTime).TotalSeconds

        if ($AgeSeconds -lt $MinimumFileAgeSeconds) {
            Write-Log "Skipping $($File.Name). File is only $([math]::Round($AgeSeconds, 1)) seconds old."
            continue
        }

        $ClipInfo = Get-ClipDateInfo -File $File

        $MonthOutputPath = Join-Path $CompressedPath $ClipInfo.MonthPart
        Ensure-Folder $MonthOutputPath

        $TempName = "$([System.IO.Path]::GetFileNameWithoutExtension($File.Name))_$Profile`_$([guid]::NewGuid().ToString())$($File.Extension)"
        $TempInput = Join-Path $ProcessingPath $TempName

        $OutputCandidate = Join-Path $MonthOutputPath "$($ClipInfo.CleanName)_$OutputProfileFolder.mp4"

        if (Test-Path $OutputCandidate) {
            Write-Log "Skipping $($File.Name). Output already exists: $OutputCandidate"
            Write-Host "Skipping existing output: $OutputCandidate"
            continue
        }

        $OutputFile = Get-UniquePath -Path $OutputCandidate

        Write-Log "Copying to processing: $($File.FullName) -> $TempInput"
        Copy-Item -Path $File.FullName -Destination $TempInput -Force

        Write-Log "Encoding started: $TempInput"
        Write-Log "Output target: $OutputFile"

        if ($FrameMode -eq "cfr") {
            & $HandBrakeCLI `
                -i "$TempInput" `
                -o "$OutputFile" `
                -e $Encoder `
                -q $Quality `
                --encoder-preset $EncoderPreset `
                --rate $TargetFPS `
                --cfr `
                --width $TargetWidth `
                --height $TargetHeight `
                --keep-display-aspect `
                -E av_aac `
                -B $AudioBitrate
        }
        else {
            & $HandBrakeCLI `
                -i "$TempInput" `
                -o "$OutputFile" `
                -e $Encoder `
                -q $Quality `
                --encoder-preset $EncoderPreset `
                --rate $TargetFPS `
                --pfr `
                --width $TargetWidth `
                --height $TargetHeight `
                --keep-display-aspect `
                -E av_aac `
                -B $AudioBitrate
        }

        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputFile)) {
            $SourceSizeMB = [math]::Round((Get-Item $File.FullName).Length / 1MB, 2)
            $OutputSizeMB = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)

            if ($SourceSizeMB -gt 0) {
                $SavingsPercent = [math]::Round((1 - ($OutputSizeMB / $SourceSizeMB)) * 100, 2)
            }
            else {
                $SavingsPercent = 0
            }

            Write-Log "Encode complete. Source=${SourceSizeMB}MB Output=${OutputSizeMB}MB Saved=${SavingsPercent}%"

            if (Test-Path $TempInput) {
                Remove-Item -Path $TempInput -Force
                Write-Log "Removed temp processing copy."
            }

            if ($DeleteOriginalAfterSuccess -eq $true) {
                Remove-Item -Path $File.FullName -Force
                Write-Log "Original deleted after successful encode: $($File.FullName)"
            }
            else {
                Write-Log "Original kept in ingest for testing: $($File.FullName)"
            }
        }
        else {
            Write-Log "ERROR: Encode failed for $TempInput"

            if ($OutputFile -and (Test-Path $OutputFile)) {
                Remove-Item $OutputFile -Force
                Write-Log "Removed incomplete output file: $OutputFile"
            }

            if ($TempInput -and (Test-Path $TempInput)) {
                Remove-Item $TempInput -Force
                Write-Log "Removed temp processing copy after failed encode."
            }
        }
    }
    catch {
        Write-Log "ERROR processing $($File.Name): $($_.Exception.Message)"
        Write-Host "ERROR processing $($File.Name): $($_.Exception.Message)" -ForegroundColor Red

        if ($OutputFile -and (Test-Path $OutputFile)) {
            Remove-Item $OutputFile -Force
            Write-Log "Removed incomplete output file after exception: $OutputFile"
        }

        if ($TempInput -and (Test-Path $TempInput)) {
            Remove-Item $TempInput -Force
            Write-Log "Removed temp processing copy after exception."
        }
    }
}

Write-Log "Replay condenser run complete."
Write-Host "Replay condenser complete." -ForegroundColor Green
Write-Host "Profile: $ProfileLabel"
Write-Host "Input folder: $IngestPath"
Write-Host "Compressed output: $CompressedPath"
Write-Host "Originals deleted after success: $DeleteOriginalAfterSuccess"
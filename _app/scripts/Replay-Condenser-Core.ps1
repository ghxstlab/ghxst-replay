<#
GHX Replay Condenser Core

Input queue:
C:\ReplayVault\01_COMPRESS_INGEST\input

In-progress queue:
C:\ReplayVault\01_COMPRESS_INGEST\inprogress\<Profile>

Completed originals:
C:\ReplayVault\01_COMPRESS_INGEST\complete\<Profile>\YYYY-MM
or
C:\ReplayVault\01_COMPRESS_INGEST\complete\AllProfiles\YYYY-MM

Output:
C:\ReplayVault\03_COMPRESSED\YYYY-MM

Profiles:
- Normal-CPU
- Normal-NVENC
- Aggressive-NVENC

Completion modes:
- CurrentProfile:
  Move source clip to complete after the selected profile succeeds.

- AllProfiles:
  Used for side-by-side testing. Source clip is only moved to complete
  once all required compression profile outputs exist.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Normal-CPU", "Normal-NVENC", "Aggressive-NVENC")]
    [string]$Profile,

    [ValidateSet("CurrentProfile", "AllProfiles")]
    [string]$CompletionMode = "CurrentProfile"
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

# Recommended: keep this false.
# Originals will move to complete instead of being deleted.
$DeleteOriginalAfterSuccess = $false

$MinimumFileAgeSeconds = 45
$Extensions = @("*.mp4", "*.mkv", "*.mov")

$TargetWidth  = 2560
$TargetHeight = 1440

# Used only when CompletionMode = AllProfiles
$RequiredProfilesForAllComplete = @(
    "Normal-CPU",
    "Normal-NVENC",
    "Aggressive-NVENC"
)

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

$ReplayPath         = Join-Path $BasePath "00_REPLAY"

$CompressRootPath   = Join-Path $BasePath "01_COMPRESS_INGEST"
$IngestPath         = Join-Path $CompressRootPath "input"
$InProgressRootPath = Join-Path $CompressRootPath "inprogress"
$InProgressPath     = Join-Path $InProgressRootPath $OutputProfileFolder
$CompleteRootPath   = Join-Path $CompressRootPath "complete"

$ProcessingPath     = Join-Path $BasePath "02_COMPRESS_PROCESSING"
$CompressedPath     = Join-Path $BasePath "03_COMPRESSED"
$SortedPath         = Join-Path $BasePath "04_SORTED"

$LogPath            = Join-Path $BasePath "logs"
$LogFile            = Join-Path $LogPath "replay-condenser.log"

# =========================
# Helper functions
# =========================

function Ensure-Folder {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
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

    # OBS replay naming example:
    # Replay 2026-05-16 22-53-32
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

function Get-OutputPathForProfile {
    param (
        [System.IO.FileInfo]$File,
        [string]$ProfileName
    )

    $ClipInfo = Get-ClipDateInfo -File $File
    $MonthOutputPath = Join-Path $CompressedPath $ClipInfo.MonthPart
    $OutputPath = Join-Path $MonthOutputPath "$($ClipInfo.CleanName)_$ProfileName.mp4"

    return [PSCustomObject]@{
        ClipInfo        = $ClipInfo
        MonthOutputPath = $MonthOutputPath
        OutputPath      = $OutputPath
    }
}

function Test-AllRequiredProfileOutputsExist {
    param ([System.IO.FileInfo]$File)

    foreach ($RequiredProfile in $RequiredProfilesForAllComplete) {
        $Info = Get-OutputPathForProfile -File $File -ProfileName $RequiredProfile

        if (!(Test-Path $Info.OutputPath)) {
            return $false
        }
    }

    return $true
}

function Move-SourceToComplete {
    param (
        [string]$SourcePath,
        [System.IO.FileInfo]$OriginalFile,
        [object]$ClipInfo
    )

    if (!(Test-Path $SourcePath)) {
        Write-Log "Source path not found while moving to complete: $SourcePath"
        return
    }

    if ($DeleteOriginalAfterSuccess -eq $true) {
        Remove-Item -Path $SourcePath -Force
        Write-Log "Original deleted after successful encode: $SourcePath"
        return
    }

    if ($CompletionMode -eq "AllProfiles") {
        $CompleteProfileFolder = "AllProfiles"
    }
    else {
        $CompleteProfileFolder = $OutputProfileFolder
    }

    $CompleteMonthPath = Join-Path (Join-Path $CompleteRootPath $CompleteProfileFolder) $ClipInfo.MonthPart
    Ensure-Folder $CompleteMonthPath

    $CompleteFile = Join-Path $CompleteMonthPath $OriginalFile.Name
    $CompleteFile = Get-UniquePath -Path $CompleteFile

    Move-Item -Path $SourcePath -Destination $CompleteFile -Force
    Write-Log "Original moved to complete: $CompleteFile"
}

function Move-SourceBackToInput {
    param (
        [string]$SourcePath,
        [System.IO.FileInfo]$OriginalFile
    )

    if (!(Test-Path $SourcePath)) {
        return
    }

    $ReturnPath = Join-Path $IngestPath $OriginalFile.Name
    $ReturnPath = Get-UniquePath -Path $ReturnPath

    Move-Item -Path $SourcePath -Destination $ReturnPath -Force
    Write-Log "Returned source file to input: $ReturnPath"
}

function Recover-InProgressFiles {
    $InProgressFiles = foreach ($Ext in $Extensions) {
        Get-ChildItem -Path $InProgressPath -Filter $Ext -File -ErrorAction SilentlyContinue
    }

    if (!$InProgressFiles -or $InProgressFiles.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "Recovering stale in-progress files for $ProfileLabel..." -ForegroundColor Yellow
    Write-Log "Recovering $($InProgressFiles.Count) stale in-progress file(s) for $ProfileLabel."

    foreach ($File in $InProgressFiles) {
        $ReturnPath = Join-Path $IngestPath $File.Name
        $ReturnPath = Get-UniquePath -Path $ReturnPath

        Move-Item -Path $File.FullName -Destination $ReturnPath -Force
        Write-Log "Recovered in-progress file back to input: $ReturnPath"
    }
}

function Get-QueueFiles {
    $QueueFiles = foreach ($Ext in $Extensions) {
        Get-ChildItem -Path $IngestPath -Filter $Ext -File -ErrorAction SilentlyContinue
    }

    return @($QueueFiles)
}

# =========================
# Startup checks
# =========================

$RequiredFolders = @(
    $ReplayPath,
    $CompressRootPath,
    $IngestPath,
    $InProgressRootPath,
    $InProgressPath,
    $CompleteRootPath,
    $ProcessingPath,
    $CompressedPath,
    $SortedPath,
    $LogPath
)

foreach ($Folder in $RequiredFolders) {
    Ensure-Folder $Folder
}

Write-Log "========================================"
Write-Log "GHX Replay Condenser started. Profile=$ProfileLabel Encoder=$Encoder Quality=$Quality Preset=$EncoderPreset FPS=$TargetFPS FrameMode=$FrameMode CompletionMode=$CompletionMode"

if (!(Test-Path $HandBrakeCLI)) {
    Write-Log "ERROR: HandBrakeCLI not found at $HandBrakeCLI"
    Write-Host "HandBrakeCLI not found at: $HandBrakeCLI" -ForegroundColor Red
    exit 1
}

# Recover interrupted files from previous cancelled runs
Recover-InProgressFiles

# =========================
# Find clips
# =========================

$Files = Get-QueueFiles

if (!$Files -or $Files.Count -eq 0) {
    Write-Log "No clips found in compress input queue."
    Write-Host "No clips found in $IngestPath"
    Write-Host "Move clips from 00_REPLAY to 01_COMPRESS_INGEST\input, then run again."
    exit 0
}

# Build work status
$WorkItems = foreach ($File in $Files) {
    $OutputInfo = Get-OutputPathForProfile -File $File -ProfileName $OutputProfileFolder

    [PSCustomObject]@{
        File            = $File
        ClipInfo        = $OutputInfo.ClipInfo
        MonthOutputPath = $OutputInfo.MonthOutputPath
        OutputPath      = $OutputInfo.OutputPath
        IsComplete      = Test-Path $OutputInfo.OutputPath
    }
}

# Move already-complete source files out of input where appropriate
foreach ($Item in @($WorkItems | Where-Object { $_.IsComplete -eq $true })) {
    if ($CompletionMode -eq "CurrentProfile") {
        Write-Host "Already complete, moving source to complete: $($Item.File.Name)" -ForegroundColor DarkGray
        Write-Log "Already complete for $OutputProfileFolder. Moving source to complete: $($Item.File.Name)"
        Move-SourceToComplete -SourcePath $Item.File.FullName -OriginalFile $Item.File -ClipInfo $Item.ClipInfo
    }
    elseif ($CompletionMode -eq "AllProfiles") {
        if (Test-AllRequiredProfileOutputsExist -File $Item.File) {
            Write-Host "Complete for all profiles, moving source to complete: $($Item.File.Name)" -ForegroundColor DarkGray
            Write-Log "Complete for all profiles. Moving source to complete: $($Item.File.Name)"
            Move-SourceToComplete -SourcePath $Item.File.FullName -OriginalFile $Item.File -ClipInfo $Item.ClipInfo
        }
    }
}

# Refresh queue after moving complete files
$Files = Get-QueueFiles

$WorkItems = foreach ($File in $Files) {
    $OutputInfo = Get-OutputPathForProfile -File $File -ProfileName $OutputProfileFolder

    [PSCustomObject]@{
        File            = $File
        ClipInfo        = $OutputInfo.ClipInfo
        MonthOutputPath = $OutputInfo.MonthOutputPath
        OutputPath      = $OutputInfo.OutputPath
        IsComplete      = Test-Path $OutputInfo.OutputPath
    }
}

$CompletedItems = @($WorkItems | Where-Object { $_.IsComplete -eq $true })
$PendingItems   = @($WorkItems | Where-Object { $_.IsComplete -eq $false })

Write-Host ""
Write-Host "Profile status: $ProfileLabel" -ForegroundColor Cyan
Write-Host "Completion mode: $CompletionMode" -ForegroundColor DarkGray
Write-Host "Total clips in input: $($WorkItems.Count)" -ForegroundColor White
Write-Host "Already complete:    $($CompletedItems.Count)" -ForegroundColor Green
Write-Host "Still pending:       $($PendingItems.Count)" -ForegroundColor Yellow
Write-Host ""

Write-Log "Profile status. TotalInput=$($WorkItems.Count) Complete=$($CompletedItems.Count) Pending=$($PendingItems.Count)"

if ($PendingItems.Count -eq 0) {
    Write-Host "Everything is already complete for this profile." -ForegroundColor Green
    Write-Log "Everything is already complete for this profile."
    exit 0
}

# =========================
# Process clips
# =========================

$CurrentIndex = 0
$TotalPending = $PendingItems.Count

foreach ($Item in $PendingItems) {
    $CurrentIndex++

    $File = $Item.File
    $ClipInfo = $Item.ClipInfo

    $InProgressFile = $null
    $TempInput = $null
    $OutputFile = $null

    try {
        Write-Log "Checking clip: $($File.Name)"

        $AgeSeconds = ((Get-Date) - $File.LastWriteTime).TotalSeconds

        if ($AgeSeconds -lt $MinimumFileAgeSeconds) {
            Write-Log "Skipping $($File.Name). File is only $([math]::Round($AgeSeconds, 1)) seconds old."
            continue
        }

        Ensure-Folder $Item.MonthOutputPath

        $OutputFile = $Item.OutputPath

        $InProgressFile = Join-Path $InProgressPath $File.Name
        $InProgressFile = Get-UniquePath -Path $InProgressFile

        $TempName = "$([System.IO.Path]::GetFileNameWithoutExtension($File.Name))_$Profile`_$([guid]::NewGuid().ToString())$($File.Extension)"
        $TempInput = Join-Path $ProcessingPath $TempName

        Write-Host ""
        Write-Host "[$CurrentIndex/$TotalPending] Encoding: $($File.Name)" -ForegroundColor Cyan
        Write-Host "Output: $OutputFile" -ForegroundColor DarkGray

        Write-Log "Moving to inprogress: $($File.FullName) -> $InProgressFile"
        Move-Item -Path $File.FullName -Destination $InProgressFile -Force

        Write-Log "Copying inprogress file to processing: $InProgressFile -> $TempInput"
        Copy-Item -Path $InProgressFile -Destination $TempInput -Force

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
            $SourceSizeMB = [math]::Round((Get-Item $InProgressFile).Length / 1MB, 2)
            $OutputSizeMB = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)

            if ($SourceSizeMB -gt 0) {
                $SavingsPercent = [math]::Round((1 - ($OutputSizeMB / $SourceSizeMB)) * 100, 2)
            }
            else {
                $SavingsPercent = 0
            }

            Write-Log "Encode complete. Source=${SourceSizeMB}MB Output=${OutputSizeMB}MB Saved=${SavingsPercent}%"
            Write-Host "Complete. Source=${SourceSizeMB}MB Output=${OutputSizeMB}MB Saved=${SavingsPercent}%" -ForegroundColor Green

            if (Test-Path $TempInput) {
                Remove-Item -Path $TempInput -Force
                Write-Log "Removed temp processing copy."
            }

            if ($CompletionMode -eq "AllProfiles") {
                if (Test-AllRequiredProfileOutputsExist -File (Get-Item $InProgressFile)) {
                    Move-SourceToComplete -SourcePath $InProgressFile -OriginalFile (Get-Item $InProgressFile) -ClipInfo $ClipInfo
                }
                else {
                    Move-SourceBackToInput -SourcePath $InProgressFile -OriginalFile (Get-Item $InProgressFile)
                    Write-Log "AllProfiles mode: not all outputs exist yet, source returned to input."
                }
            }
            else {
                Move-SourceToComplete -SourcePath $InProgressFile -OriginalFile (Get-Item $InProgressFile) -ClipInfo $ClipInfo
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

            if ($InProgressFile -and (Test-Path $InProgressFile)) {
                Move-SourceBackToInput -SourcePath $InProgressFile -OriginalFile (Get-Item $InProgressFile)
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

        if ($InProgressFile -and (Test-Path $InProgressFile)) {
            Move-SourceBackToInput -SourcePath $InProgressFile -OriginalFile (Get-Item $InProgressFile)
        }
    }
}

Write-Log "Replay condenser run complete."
Write-Host ""
Write-Host "Replay condenser complete." -ForegroundColor Green
Write-Host "Profile: $ProfileLabel"
Write-Host "Completion mode: $CompletionMode"
Write-Host "Input queue: $IngestPath"
Write-Host "In-progress queue: $InProgressPath"
Write-Host "Completed originals: $CompleteRootPath"
Write-Host "Compressed output: $CompressedPath"
Write-Host "Originals deleted after success: $DeleteOriginalAfterSuccess"
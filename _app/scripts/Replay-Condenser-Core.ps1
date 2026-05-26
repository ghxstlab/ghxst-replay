<#
GHX Replay Condenser Core

Source-safe compression queue.

Input queue:
C:\ReplayVault\01_COMPRESS_INGEST\input

Completed source archive:
C:\ReplayVault\01_COMPRESS_INGEST\complete\<Profile>\YYYY-MM
or
C:\ReplayVault\01_COMPRESS_INGEST\complete\AllProfiles\YYYY-MM

Temporary processing:
C:\ReplayVault\02_COMPRESS_PROCESSING

Output:
C:\ReplayVault\03_COMPRESSED\YYYY-MM

Important:
- Original source files stay in input until a successful output exists.
- During encode, a temporary copy is created in 02_COMPRESS_PROCESSING.
- If encode fails or is cancelled, the original remains untouched in input.
- On success, the original is moved to complete/archive.
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

$MinimumFileAgeSeconds = 45
$Extensions = @("*.mp4", "*.mkv", "*.mov")

$TargetWidth  = 2560
$TargetHeight = 1440

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

$ReplayPath       = Join-Path $BasePath "00_REPLAY"

$CompressRootPath = Join-Path $BasePath "01_COMPRESS_INGEST"
$IngestPath       = Join-Path $CompressRootPath "input"
$CompleteRootPath = Join-Path $CompressRootPath "complete"

# Legacy folder. Not used anymore, but recovered if it contains old moved originals.
$LegacyInProgressPath = Join-Path $CompressRootPath "inprogress"

$ProcessingPath   = Join-Path $BasePath "02_COMPRESS_PROCESSING"
$CompressedPath   = Join-Path $BasePath "03_COMPRESSED"
$SortedPath       = Join-Path $BasePath "04_SORTED"

$LogPath          = Join-Path $BasePath "logs"
$LogFile          = Join-Path $LogPath "replay-condenser.log"
$ProgressFile     = Join-Path $LogPath "compression-progress.txt"

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

function Update-BatchProgress {
    param (
        [string]$Status,
        [string]$ProfileLabel,
        [int]$CurrentIndex,
        [int]$TotalPending,
        [string]$FileName,
        [string]$OutputPath = ""
    )

    if ($TotalPending -le 0) {
        $Percent = 100
    }
    else {
        $Percent = [math]::Round(($CurrentIndex / $TotalPending) * 100, 1)
    }

    try {
        $Host.UI.RawUI.WindowTitle = "GHX Replay Toolkit - $ProfileLabel - $CurrentIndex/$TotalPending - $Percent%"
    }
    catch {}

    Write-Progress `
        -Activity "GHX Replay Condenser - $ProfileLabel" `
        -Status "$Status [$CurrentIndex/$TotalPending] $FileName" `
        -PercentComplete $Percent

    $ProgressText = @"
GHX Replay Toolkit - Compression Progress
Updated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Profile: $ProfileLabel
Status:  $Status

Current: $CurrentIndex / $TotalPending
Percent: $Percent%

File:    $FileName
Output:  $OutputPath
"@

    $ProgressText | Set-Content $ProgressFile
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
    Write-Log "Original source moved to complete archive: $CompleteFile"
}

function Recover-LegacyInProgressFiles {
    if (!(Test-Path $LegacyInProgressPath)) {
        return
    }

    $LegacyFiles = foreach ($Ext in $Extensions) {
        Get-ChildItem -Path $LegacyInProgressPath -Filter $Ext -Recurse -File -ErrorAction SilentlyContinue
    }

    $LegacyFiles = @($LegacyFiles)

    if ($LegacyFiles.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "Recovering $($LegacyFiles.Count) legacy in-progress source file(s) back to input..." -ForegroundColor Yellow
    Write-Log "Recovering $($LegacyFiles.Count) legacy in-progress source file(s) back to input."

    foreach ($File in $LegacyFiles) {
        $ReturnPath = Join-Path $IngestPath $File.Name
        $ReturnPath = Get-UniquePath -Path $ReturnPath

        Move-Item -Path $File.FullName -Destination $ReturnPath -Force
        Write-Log "Recovered legacy in-progress file back to input: $ReturnPath"
    }
}

function Get-QueueFiles {
    $QueueFiles = foreach ($Ext in $Extensions) {
        Get-ChildItem -Path $IngestPath -Filter $Ext -File -ErrorAction SilentlyContinue
    }

    return @($QueueFiles)
}

function Remove-TempInput {
    param ([string]$TempInput)

    if ($TempInput -and (Test-Path $TempInput)) {
        Remove-Item -Path $TempInput -Force
        Write-Log "Removed temp processing copy: $TempInput"
    }
}

function Remove-IncompleteOutput {
    param ([string]$OutputFile)

    if ($OutputFile -and (Test-Path $OutputFile)) {
        Remove-Item -Path $OutputFile -Force
        Write-Log "Removed incomplete output file: $OutputFile"
    }
}

# =========================
# Startup checks
# =========================

$RequiredFolders = @(
    $ReplayPath,
    $CompressRootPath,
    $IngestPath,
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

Recover-LegacyInProgressFiles

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

# Move already-complete source files only when safe.
foreach ($Item in @($WorkItems | Where-Object { $_.IsComplete -eq $true })) {
    if ($CompletionMode -eq "CurrentProfile") {
        Write-Host "Already complete for $OutputProfileFolder, archiving source: $($Item.File.Name)" -ForegroundColor DarkGray
        Write-Log "Already complete for $OutputProfileFolder. Moving source to complete archive: $($Item.File.Name)"
        Move-SourceToComplete -SourcePath $Item.File.FullName -OriginalFile $Item.File -ClipInfo $Item.ClipInfo
    }
    elseif ($CompletionMode -eq "AllProfiles") {
        if (Test-AllRequiredProfileOutputsExist -File $Item.File) {
            Write-Host "Complete for all profiles, archiving source: $($Item.File.Name)" -ForegroundColor DarkGray
            Write-Log "Complete for all profiles. Moving source to complete archive: $($Item.File.Name)"
            Move-SourceToComplete -SourcePath $Item.File.FullName -OriginalFile $Item.File -ClipInfo $Item.ClipInfo
        }
        else {
            Write-Log "Current profile already exists, but other profiles are missing. Keeping source in input: $($Item.File.Name)"
        }
    }
}

# Refresh queue after archiving already-complete files.
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

        $TempName = "$([System.IO.Path]::GetFileNameWithoutExtension($File.Name))_$Profile`_$([guid]::NewGuid().ToString())$($File.Extension)"
        $TempInput = Join-Path $ProcessingPath $TempName

        Write-Host ""
        Write-Host "[$CurrentIndex/$TotalPending] Encoding: $($File.Name)" -ForegroundColor Cyan
        Write-Host "Source remains safe in input until successful completion." -ForegroundColor DarkGray
        Write-Host "Output: $OutputFile" -ForegroundColor DarkGray

        Update-BatchProgress `
            -Status "Encoding" `
            -ProfileLabel $ProfileLabel `
            -CurrentIndex $CurrentIndex `
            -TotalPending $TotalPending `
            -FileName $File.Name `
            -OutputPath $OutputFile

        Write-Log "Copying source file to temporary processing copy: $($File.FullName) -> $TempInput"
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
            Write-Host "Complete. Source=${SourceSizeMB}MB Output=${OutputSizeMB}MB Saved=${SavingsPercent}%" -ForegroundColor Green

            Update-BatchProgress `
                -Status "Completed" `
                -ProfileLabel $ProfileLabel `
                -CurrentIndex $CurrentIndex `
                -TotalPending $TotalPending `
                -FileName $File.Name `
                -OutputPath $OutputFile

            Remove-TempInput -TempInput $TempInput

            if ($CompletionMode -eq "AllProfiles") {
                if (Test-AllRequiredProfileOutputsExist -File $File) {
                    Move-SourceToComplete -SourcePath $File.FullName -OriginalFile $File -ClipInfo $ClipInfo
                }
                else {
                    Write-Log "AllProfiles mode: not all outputs exist yet. Source remains in input: $($File.FullName)"
                }
            }
            else {
                Move-SourceToComplete -SourcePath $File.FullName -OriginalFile $File -ClipInfo $ClipInfo
            }
        }
        else {
            Write-Log "ERROR: Encode failed for $TempInput. Source remains untouched in input."

            Remove-IncompleteOutput -OutputFile $OutputFile
            Remove-TempInput -TempInput $TempInput
        }
    }
    catch {
        Write-Log "ERROR processing $($File.Name): $($_.Exception.Message)"
        Write-Host "ERROR processing $($File.Name): $($_.Exception.Message)" -ForegroundColor Red

        Remove-IncompleteOutput -OutputFile $OutputFile
        Remove-TempInput -TempInput $TempInput

        Write-Log "Source remains untouched in input after exception: $($File.FullName)"
    }
}

Write-Progress -Activity "GHX Replay Condenser - $ProfileLabel" -Completed

try {
    $Host.UI.RawUI.WindowTitle = "GHX Replay Toolkit"
}
catch {}

Write-Log "Replay condenser run complete."
Write-Host ""
Write-Host "Replay condenser complete." -ForegroundColor Green
Write-Host "Profile: $ProfileLabel"
Write-Host "Completion mode: $CompletionMode"
Write-Host "Input queue: $IngestPath"
Write-Host "Source archive: $CompleteRootPath"
Write-Host "Temp processing: $ProcessingPath"
Write-Host "Compressed output: $CompressedPath"
Write-Host "Original source files are only moved after successful completion."
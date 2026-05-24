<#
GHX RIFE 120FPS Enhancer

Input:
C:\ReplayVault\05_RIFE_INGEST

Processing:
C:\ReplayVault\06_RIFE_PROCESSING

Output:
C:\ReplayVault\07_RIFE_OUTPUT\YYYY-MM
#>

$ScriptRoot = $PSScriptRoot
$AppPath    = Split-Path $ScriptRoot -Parent
$BasePath   = Split-Path $AppPath -Parent

$FFmpeg  = Join-Path $AppPath "bin\ffmpeg\bin\ffmpeg.exe"
$FFprobe = Join-Path $AppPath "bin\ffmpeg\bin\ffprobe.exe"

$RifeFolder = Join-Path $AppPath "bin\rife-ncnn-vulkan"
$RifeExe    = Join-Path $RifeFolder "rife-ncnn-vulkan.exe"

$DeleteOriginalAfterSuccess = $false

$Extensions = @("*.mp4", "*.mkv", "*.mov")

$TargetFPS    = 120
$VideoCQ      = 19
$AudioBitrate = 192

$MinimumFileAgeSeconds = 30

$RifeIngestPath     = Join-Path $BasePath "05_RIFE_INGEST"
$RifeProcessingPath = Join-Path $BasePath "06_RIFE_PROCESSING"
$RifeOutputPath     = Join-Path $BasePath "07_RIFE_OUTPUT"
$LogPath            = Join-Path $BasePath "logs"
$LogFile            = Join-Path $LogPath "rife-enhance-120.log"

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

function Test-HasAudio {
    param ([string]$InputFile)

    $Result = & $FFprobe `
        -v error `
        -select_streams a:0 `
        -show_entries stream=index `
        -of csv=p=0 `
        "$InputFile"

    return -not [string]::IsNullOrWhiteSpace($Result)
}

$RequiredFolders = @(
    $RifeIngestPath,
    $RifeProcessingPath,
    $RifeOutputPath,
    $LogPath
)

foreach ($Folder in $RequiredFolders) {
    Ensure-Folder $Folder
}

Write-Log "========================================"
Write-Log "GHX RIFE enhancement started. TargetFPS=$TargetFPS VideoCQ=$VideoCQ DeleteOriginalAfterSuccess=$DeleteOriginalAfterSuccess"

if (!(Test-Path $FFmpeg)) {
    Write-Log "ERROR: FFmpeg not found at $FFmpeg"
    Write-Host "FFmpeg not found at: $FFmpeg" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $FFprobe)) {
    Write-Log "ERROR: FFprobe not found at $FFprobe"
    Write-Host "FFprobe not found at: $FFprobe" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $RifeExe)) {
    Write-Log "ERROR: rife-ncnn-vulkan not found at $RifeExe"
    Write-Host "rife-ncnn-vulkan not found at: $RifeExe" -ForegroundColor Red
    exit 1
}

$Files = foreach ($Ext in $Extensions) {
    Get-ChildItem -Path $RifeIngestPath -Filter $Ext -File -ErrorAction SilentlyContinue
}

if (!$Files -or $Files.Count -eq 0) {
    Write-Log "No clips found in RIFE ingest folder."
    Write-Host "No clips found in $RifeIngestPath"
    Write-Host "Put a manually cut clip into 05_RIFE_INGEST, then run again."
    exit 0
}

Write-Log "Found $($Files.Count) clip(s)."

foreach ($File in $Files) {
    $WorkPath   = $null
    $FramesIn   = $null
    $FramesOut  = $null
    $AudioPath  = $null
    $OutputFile = $null

    try {
        Write-Log "Checking clip: $($File.Name)"

        $AgeSeconds = ((Get-Date) - $File.LastWriteTime).TotalSeconds

        if ($AgeSeconds -lt $MinimumFileAgeSeconds) {
            Write-Log "Skipping $($File.Name). File is only $([math]::Round($AgeSeconds, 1)) seconds old."
            continue
        }

        $SafeName  = Get-SafeName -Name $File.Name
        $MonthPart = $File.LastWriteTime.ToString("yyyy-MM")

        $MonthOutputPath = Join-Path $RifeOutputPath $MonthPart
        Ensure-Folder $MonthOutputPath

        $OutputCandidate = Join-Path $MonthOutputPath "$SafeName`_RIFE-120.mp4"

        if (Test-Path $OutputCandidate) {
            Write-Log "Skipping $($File.Name). Output already exists: $OutputCandidate"
            Write-Host "Skipping existing output: $OutputCandidate"
            continue
        }

        $OutputFile = Get-UniquePath -Path $OutputCandidate

        $WorkPath  = Join-Path $RifeProcessingPath "$SafeName`_$([guid]::NewGuid().ToString())"
        $FramesIn  = Join-Path $WorkPath "frames_in"
        $FramesOut = Join-Path $WorkPath "frames_out"
        $AudioDir  = Join-Path $WorkPath "audio"
        $AudioPath = Join-Path $AudioDir "audio.mka"

        Ensure-Folder $WorkPath
        Ensure-Folder $FramesIn
        Ensure-Folder $FramesOut
        Ensure-Folder $AudioDir

        Write-Host ""
        Write-Host "Processing RIFE clip: $($File.Name)" -ForegroundColor Cyan

        Write-Log "Extracting frames..."
        Write-Host "Extracting frames..." -ForegroundColor Yellow

        & $FFmpeg `
            -y `
            -i "$($File.FullName)" `
            -vsync 0 `
            "$FramesIn\%08d.png"

        if ($LASTEXITCODE -ne 0) {
            throw "FFmpeg frame extraction failed."
        }

        Write-Log "Running RIFE interpolation..."
        Write-Host "Running RIFE interpolation..." -ForegroundColor Yellow

        Push-Location $RifeFolder

        & $RifeExe `
            -i "$FramesIn" `
            -o "$FramesOut"

        $RifeExitCode = $LASTEXITCODE

        Pop-Location

        if ($RifeExitCode -ne 0) {
            throw "RIFE interpolation failed."
        }

        $HasAudio = Test-HasAudio -InputFile $File.FullName

        if ($HasAudio) {
            Write-Log "Extracting audio..."
            Write-Host "Extracting audio..." -ForegroundColor Yellow

            & $FFmpeg `
                -y `
                -i "$($File.FullName)" `
                -vn `
                -c:a copy `
                "$AudioPath"

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Audio copy failed. Retrying with AAC extraction..."

                & $FFmpeg `
                    -y `
                    -i "$($File.FullName)" `
                    -vn `
                    -c:a aac `
                    -b:a "$($AudioBitrate)k" `
                    "$AudioPath"

                if ($LASTEXITCODE -ne 0) {
                    throw "FFmpeg audio extraction failed."
                }
            }
        }
        else {
            Write-Log "No audio stream detected."
        }

        Write-Log "Rebuilding $TargetFPS FPS video..."
        Write-Host "Rebuilding $TargetFPS FPS video..." -ForegroundColor Yellow

        if ($HasAudio) {
            & $FFmpeg `
                -y `
                -framerate $TargetFPS `
                -i "$FramesOut\%08d.png" `
                -i "$AudioPath" `
                -c:v hevc_nvenc `
                -preset p7 `
                -tune hq `
                -cq $VideoCQ `
                -pix_fmt yuv420p `
                -c:a aac `
                -b:a "$($AudioBitrate)k" `
                -shortest `
                "$OutputFile"
        }
        else {
            & $FFmpeg `
                -y `
                -framerate $TargetFPS `
                -i "$FramesOut\%08d.png" `
                -c:v hevc_nvenc `
                -preset p7 `
                -tune hq `
                -cq $VideoCQ `
                -pix_fmt yuv420p `
                "$OutputFile"
        }

        if ($LASTEXITCODE -ne 0 -or !(Test-Path $OutputFile)) {
            throw "FFmpeg final video rebuild failed."
        }

        $SourceSizeMB = [math]::Round((Get-Item $File.FullName).Length / 1MB, 2)
        $OutputSizeMB = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)

        Write-Log "RIFE complete. Source=${SourceSizeMB}MB Output=${OutputSizeMB}MB"
        Write-Host "RIFE complete. Source=${SourceSizeMB}MB Output=${OutputSizeMB}MB" -ForegroundColor Green

        if (Test-Path $WorkPath) {
            Remove-Item -Path $WorkPath -Recurse -Force
            Write-Log "Cleaned work folder: $WorkPath"
        }

        if ($DeleteOriginalAfterSuccess -eq $true) {
            Remove-Item -Path $File.FullName -Force
            Write-Log "Original source clip deleted after success: $($File.FullName)"
        }
        else {
            Write-Log "Original source clip kept: $($File.FullName)"
        }
    }
    catch {
        Write-Log "ERROR processing $($File.Name): $($_.Exception.Message)"
        Write-Host "ERROR processing $($File.Name): $($_.Exception.Message)" -ForegroundColor Red

        if ($OutputFile -and (Test-Path $OutputFile)) {
            Remove-Item -Path $OutputFile -Force
            Write-Log "Removed incomplete output file: $OutputFile"
        }

        if ($WorkPath -and (Test-Path $WorkPath)) {
            Write-Log "Keeping failed work folder for troubleshooting: $WorkPath"
            Write-Host "Failed work folder kept for troubleshooting:"
            Write-Host $WorkPath
        }
    }
}

Write-Log "RIFE enhancement run complete."
Write-Host ""
Write-Host "RIFE enhancement complete." -ForegroundColor Green
Write-Host "Input folder: $RifeIngestPath"
Write-Host "Output folder: $RifeOutputPath"
Write-Host "Processing folder: $RifeProcessingPath"
Write-Host "Originals deleted after success: $DeleteOriginalAfterSuccess"
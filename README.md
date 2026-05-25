# GHX Replay Toolkit

GHX Replay Toolkit is a Windows-based replay workflow for OBS clips.

It is designed for people who record gameplay with OBS Replay Buffer and want an easy folder-based workflow for compressing, enhancing, and organizing clips.

## Features

- Compress clips with HandBrakeCLI
- CPU x265 compression
- NVIDIA NVENC H.265 compression
- Aggressive NVENC compression
- RIFE 120 FPS enhancement
- Queue-based compression workflow
- Clean ingest, processing, output, and sorting folders
- Simple PowerShell menu launcher
- Self-contained app layout using `_app`

## Quick Start

### First Run

1. Clone or download this repo to:

```text
C:\ReplayVault
```

2. Open the folder:

```text
C:\ReplayVault
```

3. Run the installer:

```text
INSTALL.bat
```

This downloads the required portable tools into `_app\bin`:

- FFmpeg
- FFprobe
- HandBrakeCLI
- rife-ncnn-vulkan

4. After the installer finishes, run:

```text
START.bat
```

This opens the GHX Replay Toolkit menu.

### Normal Use

After the first install, you only need to run:

```text
START.bat
```

### Updating

If installed with Git, update with:

```powershell
cd C:\ReplayVault
git pull
```

Then run:

```text
INSTALL.bat
```

again only if tools are missing or the installer has been updated.

## Compression Profiles

The compression workflow uses HandBrakeCLI.

| Profile | Description |
|---|---|
| Normal CPU | Best quality/size ratio, slower, uses CPU x265 |
| Normal NVENC | Fast H.265 compression using NVIDIA NVENC |
| Aggressive NVENC | Smaller files, more visible quality loss possible |

## Compression Queue Workflow

Compression now uses a queue-based folder system:

```text
C:\ReplayVault\01_COMPRESS_INGEST\
├── input
├── inprogress
└── complete
```

### input

Put clips here when you want to compress them:

```text
C:\ReplayVault\01_COMPRESS_INGEST\input
```

### inprogress

The toolkit moves the current clip into an in-progress folder while it is being processed:

```text
C:\ReplayVault\01_COMPRESS_INGEST\inprogress
```

If the script is cancelled mid-way, the next run will recover stale in-progress files back into the input queue.

### complete

After a successful compression run, source clips are moved to:

```text
C:\ReplayVault\01_COMPRESS_INGEST\complete
```

This makes it easier to see what has already been processed and to manually delete or archive originals later.

## Completion Modes

The compression core supports two completion modes.

### CurrentProfile

Used when running a single compression profile.

After the selected profile succeeds, the source clip moves to:

```text
01_COMPRESS_INGEST\complete\<Profile>\YYYY-MM
```

### AllProfiles

Used when running all compression profiles for side-by-side comparison.

The source clip only moves to complete once all required profile outputs exist:

- Normal CPU
- Normal NVENC
- Aggressive NVENC

Completed originals move to:

```text
01_COMPRESS_INGEST\complete\AllProfiles\YYYY-MM
```

## RIFE 120 FPS Enhancement

The RIFE workflow is separate from normal compression.

It is intended for short manually cut highlight clips.

You first cut the exact clip you want, then place it into the RIFE ingest folder. The toolkit extracts frames, runs RIFE interpolation, and rebuilds a smooth 120 FPS output.

## Folder Workflow

OBS should save raw recordings or replay buffer clips to:

```text
C:\ReplayVault\00_REPLAY
```

For normal compression, move clips into:

```text
C:\ReplayVault\01_COMPRESS_INGEST\input
```

Compressed outputs go to:

```text
C:\ReplayVault\03_COMPRESSED
```

For RIFE 120 FPS enhancement, manually cut a short clip first, then move it into:

```text
C:\ReplayVault\05_RIFE_INGEST
```

RIFE outputs go to:

```text
C:\ReplayVault\07_RIFE_OUTPUT
```

## App Layout

```text
C:\ReplayVault\
├── _app
│   ├── bin
│   │   ├── ffmpeg
│   │   ├── HandBrakeCLI
│   │   └── rife-ncnn-vulkan
│   ├── scripts
│   └── launchers
│
├── 00_REPLAY
├── 01_COMPRESS_INGEST
│   ├── input
│   ├── inprogress
│   └── complete
├── 02_COMPRESS_PROCESSING
├── 03_COMPRESSED
├── 04_SORTED
├── 05_RIFE_INGEST
├── 06_RIFE_PROCESSING
├── 07_RIFE_OUTPUT
└── logs
```

## Requirements

- Windows 10 or Windows 11
- PowerShell 7+ recommended
- Windows PowerShell fallback supported
- NVIDIA GPU recommended for NVENC and RIFE
- OBS for replay recording
- Git, if installing through GitHub

The toolkit uses the following third-party tools:

- HandBrakeCLI
- FFmpeg / FFprobe
- rife-ncnn-vulkan

These tools are not committed to the Git repository. They are downloaded locally into:

```text
C:\ReplayVault\_app\bin
```

by running:

```text
C:\ReplayVault\INSTALL.bat
```

## Usage

Run the main launcher:

```text
C:\ReplayVault\START.bat
```

From the menu you can:

- Run Normal CPU compression
- Run Normal NVENC compression
- Run Aggressive NVENC compression
- Run all compression profiles
- Run RIFE 120 FPS enhancement
- Open workflow folders
- Open logs

## Recommended OBS Setup

Set your OBS Replay Buffer or Recording output folder to:

```text
C:\ReplayVault\00_REPLAY
```

This keeps OBS separate from the processing workflows.

From there:

- Move clips to `01_COMPRESS_INGEST\input` for compression.
- Cut short clips and move them to `05_RIFE_INGEST` for RIFE enhancement.

## Compression Workflow

1. Save replay from OBS.
2. Move the clip from:

```text
C:\ReplayVault\00_REPLAY
```

to:

```text
C:\ReplayVault\01_COMPRESS_INGEST\input
```

3. Run:

```text
C:\ReplayVault\START.bat
```

4. Choose a compression option.

Outputs will appear in:

```text
C:\ReplayVault\03_COMPRESSED
```

Source clips will move to:

```text
C:\ReplayVault\01_COMPRESS_INGEST\complete
```

after successful processing.

## RIFE Workflow

1. Take a raw OBS replay or recording.
2. Cut the exact short highlight clip you want to enhance.
3. Move that short clip to:

```text
C:\ReplayVault\05_RIFE_INGEST
```

4. Run:

```text
C:\ReplayVault\START.bat
```

5. Choose the RIFE 120 FPS option.

Outputs will appear in:

```text
C:\ReplayVault\07_RIFE_OUTPUT
```

## Updating

If installed with Git:

```powershell
cd C:\ReplayVault
git pull
```

Then optionally run:

```text
INSTALL.bat
```

## Notes

The repository is designed to stay lightweight.

The following are ignored by Git:

- Downloaded tools in `_app\bin`
- Temporary downloads
- OBS recordings
- Compressed outputs
- RIFE outputs
- Logs
- Extracted frames
- Video/media files

This allows the toolkit to be updated with `git pull` without storing large binaries or video files in Git.
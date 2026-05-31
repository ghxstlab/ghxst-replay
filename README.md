# GHXST Replay Toolkit

<p align="center">
  <strong>Replay compression, enhancement, and organization toolkit for OBS clips.</strong>
</p>

<p align="center">
  A Windows-based workflow for turning raw OBS Replay Buffer clips into compressed, sorted, and enhanced highlight-ready files.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows-0ea5e9?style=for-the-badge" alt="Windows">
  <img src="https://img.shields.io/badge/OBS-Replay%20Buffer-8b5cf6?style=for-the-badge" alt="OBS Replay Buffer">
  <img src="https://img.shields.io/badge/codec-H.265%20%2F%20HEVC-22c55e?style=for-the-badge" alt="H.265">
  <img src="https://img.shields.io/badge/RIFE-120%20FPS-f97316?style=for-the-badge" alt="RIFE 120 FPS">
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#folder-workflow">Folder Workflow</a> •
  <a href="#compression-workflow">Compression</a> •
  <a href="#rife-workflow">RIFE</a> •
  <a href="#requirements">Requirements</a>
</p>

---

## What is GHXST Replay Toolkit?

**GHXST Replay Toolkit** is a Windows-based replay workflow for OBS clips.

It is designed for people who record gameplay using **OBS Replay Buffer** and want a clean folder-based system for:

* compressing clips
* comparing compression profiles
* enhancing short highlight clips with RIFE
* organizing replay outputs
* keeping raw recordings separate from processed files

The toolkit is built around a simple folder pipeline:

```text
OBS Replay Buffer
→ ingest folder
→ processing folder
→ compressed/enhanced output
→ sorted/archive folder
```

---

## Why it exists

Raw OBS clips can quickly become large, messy, and hard to manage.

GHXST Replay Toolkit gives you a structured local workflow so you can:

* keep OBS recordings separate from processing
* compress clips without manually typing commands
* use CPU or GPU encoding profiles
* recover safely from interrupted jobs
* run RIFE interpolation on short highlight clips
* keep the Git repository lightweight by ignoring media and downloaded tools

---

## Features

Current features include:

* OBS Replay Buffer workflow
* Clean folder-based ingest system
* HandBrakeCLI compression
* CPU x265 compression
* NVIDIA NVENC H.265 compression
* Aggressive NVENC compression profile
* Queue-based compression workflow
* Safe `input`, `inprogress`, and `complete` folders
* Stale job recovery for interrupted compression runs
* RIFE 120 FPS enhancement workflow
* Separate RIFE ingest, processing, and output folders
* Simple PowerShell/classic menu launcher
* Self-contained `_app` layout
* Local portable tools downloaded into `_app\bin`
* Logs folder for troubleshooting

---

## Quick Start

### 1. Clone or download the repo

Recommended install path:

```text
C:\ReplayVault
```

### 2. Open the folder

```text
C:\ReplayVault
```

### 3. Install required tools

Run:

```text
01_INSTALL_TOOLS.bat
```

This downloads the required portable tools into:

```text
C:\ReplayVault\_app\bin
```

Tools include:

* FFmpeg
* FFprobe
* HandBrakeCLI
* rife-ncnn-vulkan

### 4. Start the toolkit

Run:

```text
04_START_CLASSIC_MENU.bat
```

This opens the GHXST Replay Toolkit menu.

---

## Normal Use

After first setup, normal use is simple:

```text
04_START_CLASSIC_MENU.bat
```

From the menu, you can:

* run Normal CPU compression
* run Normal NVENC compression
* run Aggressive NVENC compression
* run all compression profiles
* run RIFE 120 FPS enhancement
* open workflow folders
* open logs

---

## Recommended OBS Setup

Set your OBS Replay Buffer or Recording output folder to:

```text
C:\ReplayVault\00_REPLAY
```

This keeps OBS output separate from processing folders.

Recommended flow:

```text
OBS saves replay
→ clip lands in 00_REPLAY
→ move clip to compression or RIFE ingest
→ run toolkit
→ collect output
```

---

## Folder Workflow

Main folder layout:

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
├── _docs
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

---

## Key Folders

### `00_REPLAY`

OBS should save raw clips here:

```text
C:\ReplayVault\00_REPLAY
```

This is your raw capture/replay holding area.

### `01_COMPRESS_INGEST\input`

Put clips here when you want to compress them:

```text
C:\ReplayVault\01_COMPRESS_INGEST\input
```

### `01_COMPRESS_INGEST\inprogress`

The toolkit moves the current clip here while it is being processed:

```text
C:\ReplayVault\01_COMPRESS_INGEST\inprogress
```

If a script is cancelled mid-way, the next run can recover stale in-progress files back into the input queue.

### `01_COMPRESS_INGEST\complete`

After a successful compression run, source clips are moved here:

```text
C:\ReplayVault\01_COMPRESS_INGEST\complete
```

This makes it easier to see what has already been processed and decide whether to archive or delete originals.

### `03_COMPRESSED`

Compressed outputs are saved here:

```text
C:\ReplayVault\03_COMPRESSED
```

### `05_RIFE_INGEST`

Short manually cut clips for RIFE enhancement go here:

```text
C:\ReplayVault\05_RIFE_INGEST
```

### `07_RIFE_OUTPUT`

RIFE-enhanced clips are saved here:

```text
C:\ReplayVault\07_RIFE_OUTPUT
```

---

## Compression Profiles

The compression workflow uses **HandBrakeCLI**.

| Profile          | Description                                       |
| ---------------- | ------------------------------------------------- |
| Normal CPU       | Best quality/size ratio, slower, uses CPU x265    |
| Normal NVENC     | Fast H.265 compression using NVIDIA NVENC         |
| Aggressive NVENC | Smaller files, more visible quality loss possible |

---

## Compression Workflow

### Single profile compression

1. Save a replay from OBS.
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
C:\ReplayVault\04_START_CLASSIC_MENU.bat
```

4. Choose a compression option.
5. Wait for the job to finish.

Compressed outputs appear in:

```text
C:\ReplayVault\03_COMPRESSED
```

Source clips move to:

```text
C:\ReplayVault\01_COMPRESS_INGEST\complete
```

after successful processing.

---

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

* Normal CPU
* Normal NVENC
* Aggressive NVENC

Completed originals move to:

```text
01_COMPRESS_INGEST\complete\AllProfiles\YYYY-MM
```

---

## RIFE Workflow

The RIFE workflow is separate from normal compression.

It is intended for short manually cut highlight clips.

### Recommended RIFE flow

1. Take a raw OBS replay or recording.
2. Cut the exact short highlight clip you want to enhance.
3. Move that short clip to:

```text
C:\ReplayVault\05_RIFE_INGEST
```

4. Run:

```text
C:\ReplayVault\04_START_CLASSIC_MENU.bat
```

5. Choose the RIFE 120 FPS option.

RIFE outputs appear in:

```text
C:\ReplayVault\07_RIFE_OUTPUT
```

---

## Requirements

Recommended environment:

* Windows 10 or Windows 11
* PowerShell 7+ recommended
* Windows PowerShell fallback supported
* OBS Studio for replay recording
* NVIDIA GPU recommended for NVENC
* Vulkan-capable GPU recommended for RIFE
* Git, if installing/updating through GitHub

Third-party tools used:

* HandBrakeCLI
* FFmpeg
* FFprobe
* rife-ncnn-vulkan

These tools are not committed to the Git repository. They are downloaded locally into:

```text
C:\ReplayVault\_app\bin
```

by running:

```text
01_INSTALL_TOOLS.bat
```

---

## Updating

If installed with Git:

```powershell
cd C:\ReplayVault
git pull
```

Then optionally run:

```text
01_INSTALL_TOOLS.bat
```

Run the installer again only if tools are missing or the installer has been updated.

---

## Git Ignore / Repository Design

The repository is designed to stay lightweight.

The following are ignored by Git:

* downloaded tools in `_app\bin`
* temporary downloads
* OBS recordings
* compressed outputs
* RIFE outputs
* logs
* extracted frames
* video/media files

This allows the toolkit to be updated with:

```powershell
git pull
```

without storing large binaries or video files in Git.

---

## Troubleshooting

### Tools are missing

Run:

```text
01_INSTALL_TOOLS.bat
```

Then confirm tools exist under:

```text
C:\ReplayVault\_app\bin
```

### Compression does not start

Check that your clips are in:

```text
C:\ReplayVault\01_COMPRESS_INGEST\input
```

Also check the `logs` folder.

### A job was interrupted

The toolkit uses an `inprogress` folder so interrupted files can be recovered on the next run.

Check:

```text
C:\ReplayVault\01_COMPRESS_INGEST\inprogress
```

If needed, manually move stale clips back to:

```text
C:\ReplayVault\01_COMPRESS_INGEST\input
```

### RIFE takes very long

RIFE is much heavier than normal compression.

Use it only for short manually cut highlight clips.

---

## Documentation

Additional documentation is stored in:

```text
_docs
```

---

## Project Status

GHXST Replay Toolkit is an active local workflow project.

Current focus:

* reliable compression queue handling
* safe in-progress job recovery
* clean output folders
* RIFE workflow improvements
* easier launcher/menu experience

---

## License

See:

```text
LICENSE
```

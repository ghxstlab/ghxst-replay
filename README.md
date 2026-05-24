\# GHX Replay Toolkit



GHX Replay Toolkit is a Windows-based replay workflow for OBS clips.



It is designed for people who record gameplay with OBS Replay Buffer and want an easy folder-based workflow for:



\- Compressing clips with HandBrakeCLI

\- CPU x265 compression

\- NVIDIA NVENC H.265 compression

\- Aggressive NVENC compression

\- RIFE 120 FPS enhancement

\- Clean ingest, processing, output, and sorting folders

\- A simple PowerShell menu launcher



\## Current Features



\### Compression Profiles



The compression workflow uses HandBrakeCLI.



Available profiles:



| Profile | Description |

|---|---|

| Normal CPU | Best quality/size ratio, slower, uses CPU x265 |

| Normal NVENC | Fast H.265 compression using NVIDIA NVENC |

| Aggressive NVENC | Smaller files, more visible quality loss possible |



\### RIFE 120 FPS Enhancement



The RIFE workflow is separate from normal compression.



It is intended for short manually cut highlight clips.



You first cut the exact clip you want, then place it into the RIFE ingest folder. The toolkit extracts frames, runs RIFE interpolation, and rebuilds a smooth 120 FPS output.



\## Folder Workflow



OBS should save raw recordings or replay buffer clips to:



```text

C:\\ReplayVault\\00\_REPLAY

```



For normal compression, move clips into:



```text

C:\\ReplayVault\\01\_COMPRESS\_INGEST

```



Compressed outputs go to:



```text

C:\\ReplayVault\\03\_COMPRESSED

```



For RIFE 120 FPS enhancement, manually cut a short clip first, then move it into:



```text

C:\\ReplayVault\\05\_RIFE\_INGEST

```



RIFE outputs go to:



```text

C:\\ReplayVault\\07\_RIFE\_OUTPUT

```



\## Folder Layout



```text

C:\\ReplayVault\\

├── \_app

│   ├── bin

│   │   ├── ffmpeg

│   │   ├── HandBrakeCLI

│   │   └── rife-ncnn-vulkan

│   ├── scripts

│   └── launchers

│

├── 00\_REPLAY

├── 01\_COMPRESS\_INGEST

├── 02\_COMPRESS\_PROCESSING

├── 03\_COMPRESSED

├── 04\_SORTED

├── 05\_RIFE\_INGEST

├── 06\_RIFE\_PROCESSING

├── 07\_RIFE\_OUTPUT

└── logs

```



\## Requirements



\- Windows 10/11

\- PowerShell 7+

\- NVIDIA GPU recommended for NVENC and RIFE

\- OBS for replay recording

\- Git, if installing through GitHub



The toolkit uses:



\- HandBrakeCLI

\- FFmpeg / FFprobe

\- rife-ncnn-vulkan



These tools are not committed to the Git repo. They are downloaded locally into:



```text

C:\\ReplayVault\\\_app\\bin

```



by running:



```text

C:\\ReplayVault\\\_app\\launchers\\Install-GHX-Tools.bat

```



\## Usage



Run the main launcher:



```text

C:\\ReplayVault\\\_app\\launchers\\GHX-Replay-Toolkit.bat

```



From the menu you can:



\- Run Normal CPU compression

\- Run Normal NVENC compression

\- Run Aggressive NVENC compression

\- Run all compression profiles

\- Run RIFE 120 FPS enhancement

\- Open workflow folders

\- Open logs



\## Recommended OBS Setup



Set your OBS Replay Buffer / Recording output folder to:



```text

C:\\ReplayVault\\00\_REPLAY

```



This keeps OBS separate from the processing workflows.



From there:



\- Move clips to `01\_COMPRESS\_INGEST` for compression

\- Cut short clips and move them to `05\_RIFE\_INGEST` for RIFE enhancement



\## Compression Workflow



1\. Save replay from OBS.

2\. Move the clip from:



```text

C:\\ReplayVault\\00\_REPLAY

```



to:



```text

C:\\ReplayVault\\01\_COMPRESS\_INGEST

```



3\. Run:



```text

C:\\ReplayVault\\\_app\\launchers\\GHX-Replay-Toolkit.bat

```



4\. Choose a compression option.



Outputs will appear in:



```text

C:\\ReplayVault\\03\_COMPRESSED

```



\## RIFE Workflow



1\. Take a raw OBS replay or recording.

2\. Cut the exact short highlight clip you want to enhance.

3\. Move that short clip to:



```text

C:\\ReplayVault\\05\_RIFE\_INGEST

```



4\. Run:



```text

C:\\ReplayVault\\\_app\\launchers\\GHX-Replay-Toolkit.bat

```



5\. Choose the RIFE 120 FPS option.



Outputs will appear in:



```text

C:\\ReplayVault\\07\_RIFE\_OUTPUT

```



\## Updating



If installed with Git:



```powershell

cd C:\\ReplayVault

git pull

```



Then optionally run:



```text

C:\\ReplayVault\\\_app\\launchers\\Install-GHX-Tools.bat

```



\## Notes



The repository is designed to stay lightweight.



The following are ignored by Git:



\- Downloaded tools in `\_app\\bin`

\- Temporary downloads

\- OBS recordings

\- Compressed outputs

\- RIFE outputs

\- Logs

\- Extracted frames

\- Video/media files



This allows the toolkit to be updated with `git pull` without storing large binaries or video files in Git.


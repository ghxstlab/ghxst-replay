\# GHX Replay Toolkit Setup



\## 1. Install PowerShell 7



The toolkit is designed to run with PowerShell 7.



Check if it is installed:



```powershell

pwsh --version

```



If `pwsh` is not found, install PowerShell 7 from Microsoft.



\## 2. Clone the repo



Recommended install location:



```powershell

git clone https://github.com/YOUR\_USERNAME/ghx-replay-toolkit.git C:\\ReplayVault

cd C:\\ReplayVault

```



If you are not using Git yet, you can manually place the toolkit files in:



```text

C:\\ReplayVault

```



\## 3. Install dependencies



Run:



```text

C:\\ReplayVault\\\_app\\launchers\\Install-GHX-Tools.bat

```



This downloads the required portable tools into:



```text

C:\\ReplayVault\\\_app\\bin

```



Tools installed:



\- FFmpeg

\- FFprobe

\- HandBrakeCLI

\- rife-ncnn-vulkan



\## 4. Set OBS output folder



In OBS, set your replay buffer / recording output folder to:



```text

C:\\ReplayVault\\00\_REPLAY

```



This keeps raw recordings separate from processing folders.



\## 5. Run the toolkit



Run:



```text

C:\\ReplayVault\\\_app\\launchers\\GHX-Replay-Toolkit.bat

```



\## Compression Workflow



Move clips from:



```text

C:\\ReplayVault\\00\_REPLAY

```



to:



```text

C:\\ReplayVault\\01\_COMPRESS\_INGEST

```



Then run one of the compression profiles from the toolkit menu.



Outputs go to:



```text

C:\\ReplayVault\\03\_COMPRESSED

```



\## RIFE 120 FPS Workflow



Cut your clip manually first.



Move the short clip to:



```text

C:\\ReplayVault\\05\_RIFE\_INGEST

```



Then run the RIFE 120 FPS option from the toolkit menu.



Outputs go to:



```text

C:\\ReplayVault\\07\_RIFE\_OUTPUT

```



\## Updating



To update the toolkit scripts:



```powershell

cd C:\\ReplayVault

git pull

```



Then optionally run:



```text

C:\\ReplayVault\\\_app\\launchers\\Install-GHX-Tools.bat

```



\## Troubleshooting



\### The BAT file opens and closes instantly



Open PowerShell manually and run:



```powershell

pwsh -ExecutionPolicy Bypass -File "C:\\ReplayVault\\\_app\\scripts\\Run-GHX-Replay-Toolkit.ps1"

```



This will show the error message.



\### PowerShell says scripts are blocked



Run the BAT launchers. They already use:



```powershell

\-ExecutionPolicy Bypass

```



\### HandBrakeCLI not found



Run:



```text

C:\\ReplayVault\\\_app\\launchers\\Install-GHX-Tools.bat

```



Then confirm this exists:



```text

C:\\ReplayVault\\\_app\\bin\\HandBrakeCLI\\HandBrakeCLI.exe

```



\### FFmpeg not found



Confirm these exist:



```text

C:\\ReplayVault\\\_app\\bin\\ffmpeg\\bin\\ffmpeg.exe

C:\\ReplayVault\\\_app\\bin\\ffmpeg\\bin\\ffprobe.exe

```



\### RIFE not found



Confirm this exists:



```text

C:\\ReplayVault\\\_app\\bin\\rife-ncnn-vulkan\\rife-ncnn-vulkan.exe

```



\### No clips found



Make sure clips are in the correct folder.



Compression input:



```text

C:\\ReplayVault\\01\_COMPRESS\_INGEST

```



RIFE input:



```text

C:\\ReplayVault\\05\_RIFE\_INGEST

```


r"""
GHX Replay Toolkit UI v3

Polished CustomTkinter frontend for the existing GHX Replay Toolkit PowerShell backend.

Save as:
C:\ReplayVault\_app\ui\ghx_replay_toolkit.py

Run with:
python C:\ReplayVault\_app\ui\ghx_replay_toolkit.py

This UI keeps the PowerShell backend intact and calls:
- _app\scripts\Replay-Condenser-Core.ps1
- _app\scripts\Replay-Enhance-RIFE-120.ps1
- _app\scripts\Install-GHX-Tools.ps1
"""

from __future__ import annotations

import os
import queue
import subprocess
import threading
from pathlib import Path
from typing import Callable, Iterable

try:
    import customtkinter as ctk
except ImportError as exc:
    raise SystemExit(
        "customtkinter is not installed. Install it with: python -m pip install customtkinter"
    ) from exc


VIDEO_EXTENSIONS = {".mp4", ".mkv", ".mov"}


class GHXReplayToolkit(ctk.CTk):
    def __init__(self) -> None:
        super().__init__()

        self.title("GHX Replay Toolkit")
        self.geometry("1440x900")
        self.minsize(1240, 760)

        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        self.script_path = Path(__file__).resolve()
        self.ui_path = self.script_path.parent
        self.app_path = self.ui_path.parent
        self.base_path = self.app_path.parent
        self.scripts_path = self.app_path / "scripts"

        self.paths = {
            "raw": self.base_path / "00_REPLAY",
            "compress_input": self.base_path / "01_COMPRESS_INGEST" / "input",
            "compress_inprogress": self.base_path / "01_COMPRESS_INGEST" / "inprogress",
            "compress_archive": self.base_path / "01_COMPRESS_INGEST" / "complete",
            "compressed": self.base_path / "03_COMPRESSED",
            "rife_input": self.base_path / "05_RIFE_INGEST",
            "rife_output": self.base_path / "07_RIFE_OUTPUT",
            "logs": self.base_path / "logs",
        }

        self.core_script = self.scripts_path / "Replay-Condenser-Core.ps1"
        self.rife_script = self.scripts_path / "Replay-Enhance-RIFE-120.ps1"
        self.install_script = self.scripts_path / "Install-GHX-Tools.ps1"

        self.output_queue: queue.Queue[str] = queue.Queue()
        self.current_process: subprocess.Popen[str] | None = None
        self.is_running = False
        self.stop_requested = False

        self.count_labels: dict[str, ctk.CTkLabel] = {}
        self.action_buttons: list[ctk.CTkButton] = []

        self._ensure_folders()
        self._build_ui()
        self.refresh_counts(log_message=False)
        self.after(250, self._drain_output_queue)
        self.after(2000, self._auto_refresh_counts)

    # -------------------------
    # UI construction
    # -------------------------

    def _build_ui(self) -> None:
        self.grid_columnconfigure(0, weight=0)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        self.sidebar = ctk.CTkFrame(self, width=310, corner_radius=0, fg_color="#070b12")
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        self.sidebar.grid_propagate(False)

        self.main = ctk.CTkFrame(self, corner_radius=0, fg_color="#0a0f17")
        self.main.grid(row=0, column=1, sticky="nsew")
        self.main.grid_columnconfigure(0, weight=1)
        self.main.grid_rowconfigure(4, weight=1)

        self._build_sidebar()
        self._build_main()

    def _build_sidebar(self) -> None:
        logo = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        logo.pack(padx=24, pady=(28, 18), fill="x")

        ctk.CTkLabel(
            logo,
            text="GHX.ST",
            font=ctk.CTkFont(size=36, weight="bold"),
            text_color="#00e5ff",
        ).pack(anchor="w")

        ctk.CTkLabel(
            logo,
            text="Replay Toolkit",
            font=ctk.CTkFont(size=17, weight="bold"),
            text_color="#effcff",
        ).pack(anchor="w", pady=(0, 2))

        ctk.CTkLabel(
            logo,
            text="A local command center for OBS clips.\nCompress replays. Enhance highlights.\nKeep your folders clean.",
            font=ctk.CTkFont(size=12),
            text_color="#8b9aad",
            justify="left",
        ).pack(anchor="w", pady=(8, 0))

        self.status_pill = ctk.CTkLabel(
            self.sidebar,
            text="READY",
            font=ctk.CTkFont(size=12, weight="bold"),
            text_color="#001015",
            fg_color="#00e5ff",
            corner_radius=18,
            height=30,
        )
        self.status_pill.pack(padx=24, pady=(4, 10), fill="x")

        self.status_label = ctk.CTkLabel(
            self.sidebar,
            text="System idle",
            font=ctk.CTkFont(size=12),
            text_color="#8b9aad",
            justify="left",
            wraplength=250,
        )
        self.status_label.pack(padx=24, pady=(0, 16), anchor="w")

        self._sidebar_button("Refresh Dashboard", self.refresh_counts, "#0f91a8", "#12aeca")
        self._sidebar_button("Install / Check Tools", self.run_installer, "#182536", "#24344a")

        ctk.CTkLabel(
            self.sidebar,
            text="Workflow Folders",
            font=ctk.CTkFont(size=14, weight="bold"),
            text_color="#ffffff",
        ).pack(padx=24, pady=(22, 8), anchor="w")

        folder_buttons = [
            ("00  RAW OBS", "raw"),
            ("01  Queue Input", "compress_input"),
            ("01  Active Job", "compress_inprogress"),
            ("01  Source Archive", "compress_archive"),
            ("03  Compressed Output", "compressed"),
            ("05  RIFE Input", "rife_input"),
            ("07  RIFE Output", "rife_output"),
            ("Logs", "logs"),
        ]

        for label, key in folder_buttons:
            self._sidebar_button(label, lambda k=key: self.open_folder(k), "#111927", "#1c2a3d")

        ctk.CTkLabel(
            self.sidebar,
            text=f"Root: {self.base_path}",
            font=ctk.CTkFont(size=11),
            text_color="#526273",
            wraplength=245,
            justify="left",
        ).pack(padx=24, pady=(22, 0), anchor="w")

    def _sidebar_button(
        self,
        text: str,
        command: Callable[[], None],
        color: str,
        hover: str,
    ) -> None:
        ctk.CTkButton(
            self.sidebar,
            text=text,
            command=command,
            fg_color=color,
            hover_color=hover,
            anchor="w",
            height=34,
        ).pack(padx=24, pady=4, fill="x")

    def _build_main(self) -> None:
        hero = ctk.CTkFrame(self.main, fg_color="#0f1724", corner_radius=22)
        hero.grid(row=0, column=0, sticky="ew", padx=28, pady=(24, 12))
        hero.grid_columnconfigure(0, weight=1)
        hero.grid_columnconfigure(1, weight=0)

        ctk.CTkLabel(
            hero,
            text="GHX Replay Command Center",
            font=ctk.CTkFont(size=32, weight="bold"),
            text_color="#ffffff",
        ).grid(row=0, column=0, sticky="w", padx=24, pady=(18, 4))

        ctk.CTkLabel(
            hero,
            text=(
                "A cleaner workflow for OBS replays: drop clips into the queue, run a compression profile, "
                "or send trimmed highlights through RIFE for smooth 120 FPS output."
            ),
            font=ctk.CTkFont(size=14),
            text_color="#9fb0c4",
            wraplength=860,
            justify="left",
        ).grid(row=1, column=0, sticky="w", padx=24, pady=(0, 18))

        self.running_badge = ctk.CTkLabel(
            hero,
            text="SYSTEM READY",
            font=ctk.CTkFont(size=13, weight="bold"),
            text_color="#00e5ff",
        )
        self.running_badge.grid(row=0, column=1, sticky="ne", padx=24, pady=22)

        self._build_count_cards()
        self._build_workflow_help()
        self._build_actions()
        self._build_log_panel()

    def _build_count_cards(self) -> None:
        cards = ctk.CTkFrame(self.main, fg_color="transparent")
        cards.grid(row=1, column=0, sticky="ew", padx=20, pady=0)
        for i in range(5):
            cards.grid_columnconfigure(i, weight=1)

        self._add_count_card(cards, 0, "Queue Input", "compress_input", "#00e5ff", "clips waiting to compress")
        self._add_count_card(cards, 1, "Active Job", "compress_inprogress", "#ffd166", "usually 0 or 1")
        self._add_count_card(cards, 2, "Source Archive", "compress_archive", "#44ff99", "originals already processed")
        self._add_count_card(cards, 3, "Compressed Out", "compressed", "#8ab4ff", "finished compressed clips")
        self._add_count_card(cards, 4, "RIFE Input", "rife_input", "#ff66d8", "trimmed clips for 120 FPS")

    def _add_count_card(self, parent: ctk.CTkFrame, column: int, title: str, key: str, color: str, hint: str) -> None:
        card = ctk.CTkFrame(parent, fg_color="#101927", corner_radius=18)
        card.grid(row=0, column=column, padx=8, pady=8, sticky="ew")

        ctk.CTkLabel(
            card,
            text=title,
            font=ctk.CTkFont(size=13, weight="bold"),
            text_color="#d6e2f0",
        ).pack(padx=14, pady=(14, 0), anchor="w")

        value = ctk.CTkLabel(card, text="0", font=ctk.CTkFont(size=32, weight="bold"), text_color=color)
        value.pack(padx=14, pady=(2, 0), anchor="w")
        self.count_labels[key] = value

        ctk.CTkLabel(card, text=hint, font=ctk.CTkFont(size=11), text_color="#728196").pack(
            padx=14, pady=(0, 14), anchor="w"
        )

    def _build_workflow_help(self) -> None:
        help_frame = ctk.CTkFrame(self.main, fg_color="transparent")
        help_frame.grid(row=2, column=0, sticky="ew", padx=28, pady=(8, 10))
        help_frame.grid_columnconfigure(0, weight=1)
        help_frame.grid_columnconfigure(1, weight=1)

        self._info_panel(
            help_frame,
            0,
            "Compression Flow",
            "00_REPLAY → 01_COMPRESS_INGEST\\input → 03_COMPRESSED",
            "Queue Input goes down as files are processed. Compressed Out goes up as outputs are created. Source Archive stores originals that are done so you can delete or keep them later.",
            "#00e5ff",
        )
        self._info_panel(
            help_frame,
            1,
            "RIFE Enhancement Flow",
            "Cut short clip → 05_RIFE_INGEST → 07_RIFE_OUTPUT",
            "Use this only for showcase clips. RIFE creates smoother 120 FPS output, but it is heavier and best for trimmed highlights rather than full replay dumps.",
            "#ff66d8",
        )

    def _info_panel(self, parent: ctk.CTkFrame, column: int, title: str, path: str, body: str, color: str) -> None:
        panel = ctk.CTkFrame(parent, fg_color="#101927", corner_radius=18)
        panel.grid(row=0, column=column, padx=8, sticky="ew")
        panel.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(panel, text=title, font=ctk.CTkFont(size=15, weight="bold"), text_color=color).grid(
            row=0, column=0, sticky="w", padx=16, pady=(14, 2)
        )
        ctk.CTkLabel(panel, text=path, font=ctk.CTkFont(size=12, weight="bold"), text_color="#ffffff").grid(
            row=1, column=0, sticky="w", padx=16, pady=(2, 4)
        )
        ctk.CTkLabel(
            panel,
            text=body,
            font=ctk.CTkFont(size=12),
            text_color="#8f9db0",
            wraplength=520,
            justify="left",
        ).grid(row=2, column=0, sticky="w", padx=16, pady=(0, 14))

    def _build_actions(self) -> None:
        actions = ctk.CTkFrame(self.main, fg_color="#101927", corner_radius=18)
        actions.grid(row=3, column=0, sticky="ew", padx=28, pady=(0, 14))
        actions.grid_columnconfigure((0, 1, 2, 3, 4, 5), weight=1)

        ctk.CTkLabel(actions, text="Actions", font=ctk.CTkFont(size=17, weight="bold"), text_color="#ffffff").grid(
            row=0, column=0, columnspan=6, sticky="w", padx=16, pady=(14, 2)
        )
        ctk.CTkLabel(
            actions,
            text="Only one job runs at a time. Use Stop to cancel the active backend process; rerun later to continue from the queue.",
            font=ctk.CTkFont(size=12),
            text_color="#8f9db0",
        ).grid(row=1, column=0, columnspan=6, sticky="w", padx=16, pady=(0, 10))

        self._action_button(actions, 0, "Normal CPU", "Best quality/size\nSlower x265 encode", lambda: self.run_compression("Normal-CPU", "CurrentProfile"), "#1f6fb2", "#2e86d1")
        self._action_button(actions, 1, "Normal NVENC", "Fast H.265\nGood daily option", lambda: self.run_compression("Normal-NVENC", "CurrentProfile"), "#1f6fb2", "#2e86d1")
        self._action_button(actions, 2, "Aggressive NVENC", "Smaller files\nMore quality loss", lambda: self.run_compression("Aggressive-NVENC", "CurrentProfile"), "#1f6fb2", "#2e86d1")
        self._action_button(actions, 3, "Run All", "Side-by-side test\nComplete after all", self.run_all_compression, "#0f91a8", "#12aeca")
        self._action_button(actions, 4, "RIFE 120FPS", "Smooth highlights\nShort clips only", self.run_rife, "#913ecf", "#a855f7")
        self.stop_button = self._action_button(actions, 5, "Stop", "Cancel active job\nUse with care", self.stop_current_job, "#8a1f2d", "#b3263a")
        self.stop_button.configure(state="disabled")

    def _action_button(self, parent: ctk.CTkFrame, column: int, title: str, desc: str, command: Callable[[], None], color: str, hover: str) -> ctk.CTkButton:
        frame = ctk.CTkFrame(parent, fg_color="#0b121d", corner_radius=14)
        frame.grid(row=2, column=column, padx=8, pady=(6, 16), sticky="ew")

        btn = ctk.CTkButton(frame, text=title, command=command, fg_color=color, hover_color=hover, height=34)
        btn.pack(padx=10, pady=(10, 6), fill="x")
        self.action_buttons.append(btn)

        ctk.CTkLabel(frame, text=desc, font=ctk.CTkFont(size=11), text_color="#8795a8", justify="center").pack(
            padx=10, pady=(0, 10)
        )
        return btn

    def _build_log_panel(self) -> None:
        log_frame = ctk.CTkFrame(self.main, fg_color="#101927", corner_radius=18)
        log_frame.grid(row=4, column=0, sticky="nsew", padx=28, pady=(0, 24))
        log_frame.grid_columnconfigure(0, weight=1)
        log_frame.grid_rowconfigure(1, weight=1)

        log_header = ctk.CTkFrame(log_frame, fg_color="transparent")
        log_header.grid(row=0, column=0, sticky="ew", padx=16, pady=(14, 6))
        log_header.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(log_header, text="Live Output", font=ctk.CTkFont(size=17, weight="bold"), text_color="#ffffff").grid(
            row=0, column=0, sticky="w"
        )

        self.verbose_var = ctk.BooleanVar(value=False)
        ctk.CTkSwitch(
            log_header,
            text="Verbose",
            variable=self.verbose_var,
            progress_color="#00e5ff",
        ).grid(row=0, column=1, padx=(0, 12), sticky="e")

        ctk.CTkButton(
            log_header,
            text="Clear",
            width=90,
            command=self.clear_log,
            fg_color="#182536",
            hover_color="#24344a",
        ).grid(row=0, column=2, sticky="e")

        self.log_box = ctk.CTkTextbox(
            log_frame,
            font=ctk.CTkFont(family="Consolas", size=12),
            wrap="word",
            fg_color="#060a10",
            text_color="#e9f2ff",
        )
        self.log_box.grid(row=1, column=0, sticky="nsew", padx=16, pady=(0, 16))
        self.log("GHX Replay Toolkit UI ready.\n")
        self.log("Tip: Put compression clips into 01_COMPRESS_INGEST\\input, or short RIFE clips into 05_RIFE_INGEST.\n")

    # -------------------------
    # Actions
    # -------------------------

    def run_installer(self) -> None:
        self.run_script("Install / Check Tools", self.install_script, [])

    def run_compression(self, profile: str, completion_mode: str) -> None:
        self.run_script(
            f"Compression: {profile}",
            self.core_script,
            ["-Profile", profile, "-CompletionMode", completion_mode],
        )

    def run_all_compression(self) -> None:
        if self.is_running:
            self.log("A job is already running.\n")
            return

        def worker() -> None:
            profiles = ["Normal-CPU", "Normal-NVENC", "Aggressive-NVENC"]
            for profile in profiles:
                if self.stop_requested:
                    break
                if not self._run_process(
                    f"Compression: {profile}",
                    self.core_script,
                    ["-Profile", profile, "-CompletionMode", "AllProfiles"],
                ):
                    break
            self.output_queue.put("__JOB_DONE__")

        self._start_worker(worker, "Run All Compression")

    def run_rife(self) -> None:
        self.run_script("RIFE 120FPS Enhancement", self.rife_script, [])

    def stop_current_job(self) -> None:
        self.stop_requested = True
        self.output_queue.put("Stop requested. Attempting to terminate active process...\n")
        if self.current_process and self.current_process.poll() is None:
            try:
                self.current_process.terminate()
            except Exception as exc:  # noqa: BLE001
                self.output_queue.put(f"Could not terminate process cleanly: {exc}\n")

    def run_script(self, name: str, script: Path, args: list[str]) -> None:
        if self.is_running:
            self.log("A job is already running.\n")
            return

        def worker() -> None:
            self._run_process(name, script, args)
            self.output_queue.put("__JOB_DONE__")

        self._start_worker(worker, name)

    def _start_worker(self, target: Callable[[], None], name: str) -> None:
        self.stop_requested = False
        self.is_running = True
        self.status_label.configure(text=f"Running: {name}")
        self.status_pill.configure(text="RUNNING", fg_color="#ffd166", text_color="#1a1200")
        self.running_badge.configure(text="JOB RUNNING", text_color="#ffd166")
        self._set_buttons_state("disabled")
        self.stop_button.configure(state="normal")
        self.log(f"\n=== {name} ===\n")
        thread = threading.Thread(target=target, daemon=True)
        thread.start()

    def _run_process(self, name: str, script: Path, args: list[str]) -> bool:
        if not script.exists():
            self.output_queue.put(f"Missing script: {script}\n")
            return False

        ps_exe = self._get_powershell_exe()
        command = [ps_exe, "-ExecutionPolicy", "Bypass", "-File", str(script), *args]

        self.output_queue.put(f"Running: {name}\n")
        if self.verbose_var.get():
            self.output_queue.put(f"Command: {' '.join(command)}\n\n")

        try:
            self.current_process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                cwd=str(self.base_path),
                bufsize=1,
            )

            assert self.current_process.stdout is not None
            for line in self.current_process.stdout:
                self.output_queue.put(line)

            return_code = self.current_process.wait()
            self.output_queue.put(f"Exit code: {return_code}\n")
            return return_code == 0

        except Exception as exc:  # noqa: BLE001
            self.output_queue.put(f"ERROR running {name}: {exc}\n")
            return False
        finally:
            self.current_process = None

    # -------------------------
    # Utilities
    # -------------------------

    def _ensure_folders(self) -> None:
        for path in self.paths.values():
            path.mkdir(parents=True, exist_ok=True)

    def _get_powershell_exe(self) -> str:
        for exe in ("pwsh", "powershell"):
            try:
                subprocess.run(
                    [exe, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
                return exe
            except FileNotFoundError:
                continue
        return "powershell"

    def refresh_counts(self, log_message: bool = True) -> None:
        for key, label in self.count_labels.items():
            count = self.count_files(self.paths[key])
            label.configure(text=str(count))
        if log_message:
            self.log("Dashboard refreshed.\n")

    def _auto_refresh_counts(self) -> None:
        self.refresh_counts(log_message=False)
        self.after(2000, self._auto_refresh_counts)

    def count_files(self, path: Path) -> int:
        if not path.exists():
            return 0
        return sum(1 for _ in self._iter_video_files(path))

    def _iter_video_files(self, path: Path) -> Iterable[Path]:
        for file in path.rglob("*"):
            if file.is_file() and file.suffix.lower() in VIDEO_EXTENSIONS:
                yield file

    def open_folder(self, key: str) -> None:
        path = self.paths[key]
        path.mkdir(parents=True, exist_ok=True)
        os.startfile(path)  # type: ignore[attr-defined]

    def log(self, text: str) -> None:
        self.log_box.insert("end", text)
        self.log_box.see("end")

    def clear_log(self) -> None:
        self.log_box.delete("1.0", "end")

    def _should_show_line(self, line: str) -> bool:
        if self.verbose_var.get():
            return True

        important_terms = (
            "===",
            "Running:",
            "Profile status",
            "Total clips",
            "Already complete",
            "Still pending",
            "Encoding:",
            "Complete.",
            "Replay condenser complete",
            "RIFE complete",
            "No clips found",
            "ERROR",
            "Exit code",
            "Stop requested",
            "Extracting frames",
            "Running RIFE",
            "Rebuilding",
        )
        return any(term in line for term in important_terms)

    def _drain_output_queue(self) -> None:
        try:
            while True:
                message = self.output_queue.get_nowait()
                if message == "__JOB_DONE__":
                    self.is_running = False
                    self.stop_requested = False
                    self.status_label.configure(text="System idle")
                    self.status_pill.configure(text="READY", fg_color="#00e5ff", text_color="#001015")
                    self.running_badge.configure(text="SYSTEM READY", text_color="#00e5ff")
                    self._set_buttons_state("normal")
                    self.stop_button.configure(state="disabled")
                    self.refresh_counts(log_message=False)
                    self.log("Job finished.\n")
                else:
                    if self._should_show_line(message):
                        self.log(message)
        except queue.Empty:
            pass
        finally:
            self.after(250, self._drain_output_queue)

    def _set_buttons_state(self, state: str) -> None:
        for button in self.action_buttons:
            button.configure(state=state)


if __name__ == "__main__":
    app = GHXReplayToolkit()
    app.mainloop()

"""
run_sim.py
GHDL Simulation Runner for Configurable FSM Project
Usage: python run_sim.py  (run from the configurable_fsm/ directory)
"""

import subprocess
import threading
import tkinter as tk
from tkinter import ttk, scrolledtext
import os
import sys

# ─── Project structure ────────────────────────────────────────────────────────

SRC = "src"
TB  = "tb"
STD = "--std=08"

# Source files — order matters for analysis (dependencies first)
SRC_FILES = [
    "generic_fsm.vhd",
    "config_rom.vhd",
    "traffic_light_wrapper.vhd",
    "vending_wrapper.vhd",
    "elevator_wrapper.vhd",
    "serial_wrapper.vhd",
]

# Testbench definitions: display name, tb file, top entity, vcd output
TESTBENCHES = [
    ("FSM Core",      "tb_fsm.vhd",          "tb_fsm",          "tb_fsm.vcd"),
    ("Traffic Light", "tb_traffic_light.vhd", "tb_traffic_light","tb_traffic_light.vcd"),
    ("Vending",       "tb_vending.vhd",       "tb_vending",      "tb_vending.vcd"),
    ("Elevator",      "tb_elevator.vhd",      "tb_elevator",     "tb_elevator.vcd"),
    ("Serial",        "tb_serial.vhd",        "tb_serial",       "tb_serial.vcd"),
]

# ─── Colours ──────────────────────────────────────────────────────────────────
# Palette: deep navy base with a signature teal accent. Inspired by the look
# of oscilloscope / logic-analyser UIs — technical, confident, and rich
# without being neon.

BG         = "#0f1621"   # window background, deep navy
SURFACE    = "#1a2332"   # raised panels
SURFACE_2  = "#0a0f17"   # console inset (near-black)
BORDER     = "#243142"   # subtle dividers

ACCENT     = "#4fd1c5"   # signature teal — primary action, headers
ACCENT_DIM = "#2d7a74"   # darker teal for secondary button
NEUTRAL_BG = "#2a3647"   # tertiary button (Open Waveform, Clear)

PASS_COL   = "#6fd88c"   # confident green, not neon
FAIL_COL   = "#ff6b7a"   # clear red, still warm
WARN_COL   = "#f4c36d"   # amber
INFO_COL   = "#8ec6ff"   # cool blue for dividers / info

TEXT       = "#e4ecf7"   # primary text, bright but slightly warm
TEXT_DIM   = "#a8b6ce"   # secondary
MUTED      = "#5a6b85"   # shell prompts, timestamps

# ─── Helpers ──────────────────────────────────────────────────────────────────

def run(cmd: list[str]) -> tuple[int, str, str]:
    """Run a command, return (returncode, stdout, stderr)."""
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )
    return result.returncode, result.stdout, result.stderr


def classify_line(line: str) -> str:
    """Return a tag name for colouring a GHDL output line."""
    l = line.lower()
    if "pass:" in l:
        return "pass"
    if "fail:" in l or "error:" in l or "failure" in l:
        return "fail"
    if "warning:" in l or "warn" in l:
        return "warn"
    if "results:" in l or "===" in line or "---" in line:
        return "info"
    if "simulation finished" in l:
        return "info"
    return "normal"


# ─── Main GUI ─────────────────────────────────────────────────────────────────

class SimRunner(tk.Tk):

    def __init__(self):
        super().__init__()
        self.title("GHDL Simulation Runner — Configurable FSM")
        self.configure(bg=BG)
        self.resizable(True, True)
        self.geometry("900x650")

        # Track last VCD produced so we can open it
        self._last_vcd: str | None = None
        self._running  = False

        self._build_ui()

    # ── UI construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        # ── Header ────────────────────────────────────────────────────────────
        hdr = tk.Frame(self, bg=BG, pady=12)
        hdr.pack(fill="x", padx=20)

        tk.Label(
            hdr, text="Configurable FSM", font=("Courier New", 18, "bold"),
            bg=BG, fg=ACCENT
        ).pack(side="left")

        tk.Label(
            hdr, text="  GHDL Simulation Runner", font=("Courier New", 12),
            bg=BG, fg=TEXT_DIM
        ).pack(side="left")

        # ── Testbench selector ────────────────────────────────────────────────
        sel_frame = tk.Frame(self, bg=SURFACE, pady=10, padx=16)
        sel_frame.pack(fill="x", padx=20, pady=(0, 8))

        tk.Label(
            sel_frame, text="Testbench:", font=("Courier New", 10),
            bg=SURFACE, fg=TEXT
        ).pack(side="left", padx=(0, 10))

        self._tb_var = tk.StringVar(value=TESTBENCHES[4][0])  # default: Serial
        for (name, *_) in TESTBENCHES:
            rb = tk.Radiobutton(
                sel_frame, text=name, variable=self._tb_var, value=name,
                font=("Courier New", 10), bg=SURFACE, fg=TEXT,
                selectcolor=BG, activebackground=SURFACE,
                activeforeground=ACCENT, indicatoron=True
            )
            rb.pack(side="left", padx=8)

        # ── Buttons ───────────────────────────────────────────────────────────
        btn_frame = tk.Frame(self, bg=BG, pady=6)
        btn_frame.pack(fill="x", padx=20)

        self._btn_run = self._make_button(
            btn_frame, "▶  Run", self._on_run, ACCENT)
        self._btn_run.pack(side="left", padx=(0, 8))

        self._btn_all = self._make_button(
            btn_frame, "▶▶  Run All", self._on_run_all, ACCENT_DIM)
        self._btn_all.pack(side="left", padx=(0, 8))

        self._btn_wave = self._make_button(
            btn_frame, "〜  Open Waveform", self._on_open_wave, NEUTRAL_BG)
        self._btn_wave.pack(side="left", padx=(0, 8))
        self._btn_wave.config(state="disabled")

        self._btn_clear = self._make_button(
            btn_frame, "✕  Clear", self._on_clear, NEUTRAL_BG)
        self._btn_clear.pack(side="right")

        # ── Status bar ────────────────────────────────────────────────────────
        self._status_var = tk.StringVar(value="Ready.")
        status = tk.Label(
            btn_frame, textvariable=self._status_var,
            font=("Courier New", 9), bg=BG, fg=TEXT_DIM
        )
        status.pack(side="left", padx=16)

        # ── Output console ────────────────────────────────────────────────────
        console_frame = tk.Frame(self, bg=BG)
        console_frame.pack(fill="both", expand=True, padx=20, pady=(4, 16))

        self._console = scrolledtext.ScrolledText(
            console_frame,
            bg=SURFACE_2, fg=TEXT,
            font=("Courier New", 10),
            insertbackground=TEXT,
            relief="flat", bd=0,
            state="disabled",
            wrap="word"
        )
        self._console.pack(fill="both", expand=True)

        # Colour tags
        self._console.tag_config("pass",   foreground=PASS_COL)
        self._console.tag_config("fail",   foreground=FAIL_COL)
        self._console.tag_config("warn",   foreground=WARN_COL)
        self._console.tag_config("info",   foreground=INFO_COL)
        self._console.tag_config("normal", foreground=TEXT)
        self._console.tag_config("cmd",    foreground=MUTED)
        self._console.tag_config("header", foreground=ACCENT, font=("Courier New", 10, "bold"))

        # ── Results summary bar ───────────────────────────────────────────────
        self._result_var = tk.StringVar(value="")
        self._result_lbl = tk.Label(
            self, textvariable=self._result_var,
            font=("Courier New", 11, "bold"),
            bg=BG, fg=TEXT, pady=4
        )
        self._result_lbl.pack(fill="x", padx=20, pady=(0, 8))

    def _make_button(self, parent, text, cmd, color):
        return tk.Button(
            parent, text=text, command=cmd,
            font=("Courier New", 10, "bold"),
            bg=color, fg="white",
            activebackground=ACCENT, activeforeground="white",
            relief="flat", bd=0,
            padx=14, pady=6, cursor="hand2"
        )

    # ── Console helpers ───────────────────────────────────────────────────────

    def _write(self, text: str, tag: str = "normal"):
        self._console.config(state="normal")
        self._console.insert("end", text, tag)
        self._console.see("end")
        self._console.config(state="disabled")
        self.update_idletasks()

    def _writeln(self, text: str = "", tag: str = "normal"):
        self._write(text + "\n", tag)

    def _on_clear(self):
        self._console.config(state="normal")
        self._console.delete("1.0", "end")
        self._console.config(state="disabled")
        self._result_var.set("")
        self._status_var.set("Ready.")
        self._btn_wave.config(state="disabled")
        self._last_vcd = None

    # ── Run logic ─────────────────────────────────────────────────────────────

    def _selected_tb(self):
        name = self._tb_var.get()
        for tb in TESTBENCHES:
            if tb[0] == name:
                return tb
        return TESTBENCHES[0]

    def _on_run(self):
        if self._running:
            return
        tb = self._selected_tb()
        threading.Thread(target=self._run_tb, args=(tb,), daemon=True).start()

    def _on_run_all(self):
        if self._running:
            return
        threading.Thread(target=self._run_all_tbs, daemon=True).start()

    def _set_running(self, state: bool):
        self._running = state
        s = "disabled" if state else "normal"
        self._btn_run.config(state=s)
        self._btn_all.config(state=s)

    def _run_tb(self, tb: tuple) -> tuple[int, int]:
        """Analyse, elaborate and simulate one testbench. Returns (passes, fails)."""
        name, tb_file, entity, vcd = tb

        self._writeln(f"\n{'─'*60}", "cmd")
        self._writeln(f"  {name}", "header")
        self._writeln(f"{'─'*60}", "cmd")

        # 1. Analyse source files
        self._writeln("Analysing sources...", "cmd")
        for f in SRC_FILES:
            path = os.path.join(SRC, f)
            if not os.path.exists(path):
                self._writeln(f"  [skip] {path} not found", "warn")
                continue
            cmd = ["ghdl", "-a", STD, path]
            self._writeln(f"  $ {' '.join(cmd)}", "cmd")
            rc, out, err = run(cmd)
            if rc != 0:
                self._writeln(f"  ERROR analysing {f}", "fail")
                self._writeln(err.strip(), "fail")
                return 0, 1

        # 2. Analyse testbench
        tb_path = os.path.join(TB, tb_file)
        if not os.path.exists(tb_path):
            self._writeln(f"  ERROR: {tb_path} not found", "fail")
            return 0, 1

        cmd = ["ghdl", "-a", STD, tb_path]
        self._writeln(f"  $ {' '.join(cmd)}", "cmd")
        rc, out, err = run(cmd)
        if rc != 0:
            self._writeln("  ERROR analysing testbench", "fail")
            self._writeln(err.strip(), "fail")
            return 0, 1

        # 3. Elaborate
        cmd = ["ghdl", "-e", STD, entity]
        self._writeln(f"  $ {' '.join(cmd)}", "cmd")
        rc, out, err = run(cmd)
        if rc != 0:
            self._writeln("  ERROR elaborating", "fail")
            self._writeln(err.strip(), "fail")
            return 0, 1

        # 4. Simulate
        cmd = ["ghdl", "-r", STD, entity, f"--vcd={vcd}"]
        self._writeln(f"  $ {' '.join(cmd)}", "cmd")
        self._writeln("")
        rc, out, err = run(cmd)

        # Parse and display output
        passes = fails = 0
        combined = (out + err).splitlines()
        for line in combined:
            # Strip GHDL file/line prefix if present, keep the message
            msg = line
            if ":(report" in line or ":(assertion" in line:
                # Extract just the message part after the last colon-space
                parts = line.split("): ")
                msg = parts[-1] if len(parts) > 1 else line

            tag = classify_line(msg)
            self._writeln("  " + msg, tag)

            if "pass:" in msg.lower():
                passes += 1
            if "fail:" in msg.lower() or "error:" in msg.lower():
                fails += 1

        if rc == 0 or "simulation finished" in (out + err).lower():
            self._last_vcd = vcd
            self.after(0, lambda: self._btn_wave.config(state="normal"))

        return passes, fails

    def _run_all_tbs(self):
        self._set_running(True)
        self._result_var.set("")
        total_pass = total_fail = 0

        for tb in TESTBENCHES:
            self._status_var.set(f"Running {tb[0]}...")
            p, f = self._run_tb(tb)
            total_pass += p
            total_fail += f

        self._writeln(f"\n{'═'*60}", "info")
        self._writeln(f"  ALL TESTBENCHES COMPLETE", "header")
        self._writeln(f"  Total: {total_pass} passed  {total_fail} failed", "info")
        self._writeln(f"{'═'*60}", "info")

        self._finish_run(total_pass, total_fail)

    def _on_run(self):
        if self._running:
            return
        tb = self._selected_tb()
        def task():
            self._set_running(True)
            self._result_var.set("")
            self._status_var.set(f"Running {tb[0]}...")
            p, f = self._run_tb(tb)
            self._finish_run(p, f)
        threading.Thread(target=task, daemon=True).start()

    def _on_run_all(self):
        if self._running:
            return
        threading.Thread(target=self._run_all_tbs, daemon=True).start()

    def _finish_run(self, passes: int, fails: int):
        if fails == 0:
            self._result_var.set(f"✔  {passes} passed  —  all tests ok")
            self._result_lbl.config(fg=PASS_COL)
            self._status_var.set("Done.")
        else:
            self._result_var.set(f"✘  {passes} passed  /  {fails} failed")
            self._result_lbl.config(fg=FAIL_COL)
            self._status_var.set("Done — failures detected.")
        self._set_running(False)

    # ── Waveform ──────────────────────────────────────────────────────────────

    def _on_open_wave(self):
        if not self._last_vcd or not os.path.exists(self._last_vcd):
            self._writeln("No VCD file found. Run a simulation first.", "warn")
            return
        self._writeln(f"\nOpening {self._last_vcd} in GTKWave...", "cmd")
        try:
            subprocess.Popen(["gtkwave", self._last_vcd])
        except FileNotFoundError:
            self._writeln("GTKWave not found. Is it on your PATH?", "fail")


# ─── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Must be run from the configurable_fsm/ directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    app = SimRunner()
    app.mainloop()

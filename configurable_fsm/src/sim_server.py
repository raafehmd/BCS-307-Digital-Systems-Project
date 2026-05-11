"""
sim_server.py  —  FSM Backend Simulation Server
BCS-307 Configurable FSM Project

Exposes a REST + SSE API so the website frontend can:
  - Trigger real GHDL simulation runs
  - Parse VCD waveform output cycle-by-cycle
  - Stream live state/signal updates to the browser

Run from the configurable_fsm/ directory:
    python sim_server.py
Then open the website — the "RUN VHDL" button will connect to this server.

Endpoints:
  GET  /api/status          — server health + GHDL availability
  POST /api/run             — launch a full testbench simulation
  GET  /api/results/<id>    — fetch parsed VCD results for a run
  GET  /api/stream/<id>     — SSE stream of cycle-by-cycle state updates
  POST /api/reset           — clear server state
  GET  /api/fsm_list        — list available FSMs
"""

import os
import sys
import json
import time
import uuid
import shutil
import threading
import subprocess
import re
from pathlib import Path
from flask import Flask, jsonify, request, Response, stream_with_context
from flask_cors import CORS

app = Flask(__name__)
CORS(app, origins="*")

# ─── Project paths ────────────────────────────────────────────────────────────

# Find project root — search upward for configurable_fsm/ directory
def _find_project_root():
    """Locate the configurable_fsm/ directory containing src/ and tb/."""
    candidates = [
        Path("/tmp/project/BCS-307-Digital-Systems-Project-main/configurable_fsm"),
        Path(__file__).parent,
        Path.cwd(),
        Path.cwd() / "configurable_fsm",
        Path(__file__).parent.parent / "configurable_fsm",
    ]
    for c in candidates:
        if (c / "src").exists() and (c / "tb").exists():
            return c
    return Path.cwd()

PROJECT_ROOT = _find_project_root()
SRC_DIR  = PROJECT_ROOT / "src"
TB_DIR   = PROJECT_ROOT / "tb"
VCD_DIR  = PROJECT_ROOT / "vcd_out"
VCD_DIR.mkdir(exist_ok=True)

GHDL_STD = "--std=08"

# Source files in dependency order (must match run_sim.py)
SRC_FILES = [
    "generic_fsm.vhd",
    "config_rom.vhd",
    "traffic_light_wrapper.vhd",
    "vending_wrapper.vhd",
    "elevator_wrapper.vhd",
    "serial_wrapper.vhd",
]

# FSM testbench registry
FSM_REGISTRY = {
    "traffic": {
        "label":      "Traffic Light",
        "tb_file":    "tb_traffic_light.vhd",
        "entity":     "tb_traffic_light",
        "vcd_name":   "tb_traffic_light.vcd",
        "config_id":  "00",
        "state_names": {
            "00000": "TL_IDLE",
            "00001": "TL_RED",
            "00010": "TL_GREEN",
            "00011": "TL_YELLOW",
            "00100": "TL_PED_WAIT",
            "00101": "TL_PED_CROSS",
        },
        "state_idx": {
            "00000": 0, "00001": 1, "00010": 2,
            "00011": 3, "00100": 4, "00101": 5,
        },
        "output_bits": {
            0: "red_led", 1: "yellow_led", 2: "green_led", 3: "ped_signal",
            8: "timer_start", 9: "timer_reset",
        },
    },
    "vending": {
        "label":      "Vending Machine",
        "tb_file":    "tb_vending.vhd",
        "entity":     "tb_vending",
        "vcd_name":   "tb_vending.vcd",
        "config_id":  "01",
        "state_names": {
            "00000": "VM_IDLE",
            "00001": "VM_SELECT",
            "00010": "VM_COLLECT",
            "00011": "VM_DISPENSE",
            "00100": "VM_CHANGE",
        },
        "state_idx": {
            "00000": 0, "00001": 1, "00010": 2,
            "00011": 3, "00100": 4,
        },
        "output_bits": {
            0: "dispense_motor", 1: "change_return",
            2: "display_bit0",   3: "display_bit1",
            4: "display_bit2",   5: "display_bit3",
        },
    },
    "elevator": {
        "label":      "Elevator",
        "tb_file":    "tb_elevator.vhd",
        "entity":     "tb_elevator",
        "vcd_name":   "tb_elevator.vcd",
        "config_id":  "10",
        "state_names": {
            "00000": "EL_IDLE",
            "00001": "EL_MOVE_UP",
            "00010": "EL_MOVE_DOWN",
            "00011": "EL_DOOR_OPEN",
            "00100": "EL_DOOR_CLOSE",
            "00101": "EL_EMERGENCY",
        },
        "state_idx": {
            "00000": 0, "00001": 1, "00010": 2,
            "00011": 3, "00100": 4, "00101": 5,
        },
        "output_bits": {
            0: "motor_up", 1: "motor_down", 2: "door_open", 3: "alarm_buzzer",
        },
    },
    "serial": {
        "label":      "Serial Comm",
        "tb_file":    "tb_serial.vhd",
        "entity":     "tb_serial",
        "vcd_name":   "tb_serial.vcd",
        "config_id":  "11",
        "state_names": {
            "00000": "SP_IDLE",   "00001": "SP_START",
            "00010": "SP_BIT0",   "00011": "SP_BIT1",
            "00100": "SP_BIT2",   "00101": "SP_BIT3",
            "00110": "SP_BIT4",   "00111": "SP_BIT5",
            "01000": "SP_BIT6",   "01001": "SP_BIT7",
            "01010": "SP_STOP",   "01011": "SP_COMPLETE",
        },
        "state_idx": {
            "00000": 0, "00001": 1, "00010": 2, "00011": 3,
            "00100": 4, "00101": 5, "00110": 6, "00111": 7,
            "01000": 8, "01001": 9, "01010": 10, "01011": 11,
        },
        "output_bits": {
            8: "tx_enable", 9: "parity_err",
        },
    },
    "fsm_core": {
        "label":      "FSM Core",
        "tb_file":    "tb_fsm.vhd",
        "entity":     "tb_fsm",
        "vcd_name":   "tb_fsm.vcd",
        "config_id":  "XX",
        "state_names": {},
        "state_idx":  {},
        "output_bits": {},
    },
}

# ─── In-memory run store ──────────────────────────────────────────────────────

class SimRun:
    """Holds state for one simulation run."""
    def __init__(self, run_id: str, fsm: str):
        self.run_id  = run_id
        self.fsm     = fsm
        self.status  = "pending"   # pending | running | done | error
        self.started = time.time()
        self.finished: float | None = None
        self.stdout_lines: list[str] = []
        self.stderr_lines: list[str] = []
        self.ghdl_rc: int | None = None
        self.vcd_path: Path | None = None
        self.cycles: list[dict] = []     # parsed VCD cycles
        self.passes: int = 0
        self.fails:  int = 0
        self.error_msg: str = ""
        self._lock = threading.Lock()
        self._done_event = threading.Event()

    def append_stdout(self, line: str):
        with self._lock:
            self.stdout_lines.append(line)
            l = line.lower()
            if "pass:" in l: self.passes += 1
            if "fail:" in l or ("error:" in l and "simulation" not in l): self.fails += 1

    def to_summary(self) -> dict:
        with self._lock:
            return {
                "run_id":  self.run_id,
                "fsm":     self.fsm,
                "status":  self.status,
                "started": self.started,
                "finished":self.finished,
                "passes":  self.passes,
                "fails":   self.fails,
                "cycle_count": len(self.cycles),
                "error":   self.error_msg,
            }


_runs: dict[str, SimRun] = {}
_runs_lock = threading.Lock()

# ─── GHDL helpers ─────────────────────────────────────────────────────────────

def _ghdl_available() -> bool:
    try:
        r = subprocess.run(["ghdl", "--version"], capture_output=True, timeout=5)
        return r.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _run_cmd(cmd: list[str], cwd: Path) -> tuple[int, str, str]:
    """Run a subprocess and return (rc, stdout, stderr)."""
    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True,
            cwd=str(cwd), timeout=120
        )
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "TIMEOUT: simulation exceeded 120 s"
    except FileNotFoundError as e:
        return -1, "", f"NOT FOUND: {e}"


# ─── VCD Parser ───────────────────────────────────────────────────────────────

class VCDParser:
    """
    Lightweight VCD parser that extracts signal changes per timestamp.
    Returns a list of cycle-snapshots, one per rising clock edge.
    """

    def parse(self, vcd_path: Path) -> list[dict]:
        """Parse a VCD file and return a list of cycle snapshots."""
        if not vcd_path.exists():
            return []

        text = vcd_path.read_text(errors="replace")
        signals, timescale_ps = self._parse_header(text)
        events = self._parse_events(text, signals)
        cycles = self._build_cycles(events, signals)
        return cycles

    def _parse_header(self, text: str) -> tuple[dict, int]:
        """Extract signal id→name mapping and timescale."""
        signals: dict[str, dict] = {}   # id → {name, width, type}
        timescale_ps = 1000             # default 1 ns = 1000 ps

        # timescale
        ts_m = re.search(r'\$timescale\s+([\d.]+)\s*(\w+)\s*\$end', text)
        if ts_m:
            val, unit = float(ts_m.group(1)), ts_m.group(2).lower()
            mult = {"ps": 1, "ns": 1000, "us": 1_000_000, "ms": 1_000_000_000}.get(unit, 1000)
            timescale_ps = int(val * mult)

        # Signal declarations: $var type width id name $end
        for m in re.finditer(
            r'\$var\s+(\w+)\s+(\d+)\s+(\S+)\s+(\S+)(?:\s+\[\d+:\d+\])?\s*\$end',
            text
        ):
            sig_type, width, sig_id, name = m.group(1), int(m.group(2)), m.group(3), m.group(4)
            signals[sig_id] = {"name": name, "width": width, "type": sig_type}

        return signals, timescale_ps

    def _parse_events(self, text: str, signals: dict) -> list[tuple]:
        """Extract (timestamp_ps, sig_id, value) tuples from the simulation body."""
        events: list[tuple] = []
        # Find the $dumpvars ... $end block to get start of simulation data
        body_start = text.find("$dumpvars")
        if body_start < 0:
            body_start = text.find("$end", text.find("$var"))

        body = text[body_start:] if body_start >= 0 else text
        current_time = 0

        for line in body.splitlines():
            line = line.strip()
            if not line or line.startswith("$"):
                continue
            # Timestamp
            if line.startswith("#"):
                try:
                    current_time = int(line[1:])
                except ValueError:
                    pass
                continue
            # Scalar: 0x, 1x, Zx, Xx
            scalar_m = re.match(r'^([01xzXZ])(\S+)$', line)
            if scalar_m:
                val = scalar_m.group(1)
                sig_id = scalar_m.group(2)
                if sig_id in signals:
                    events.append((current_time, sig_id, val))
                continue
            # Vector: b<bits> <id>
            vec_m = re.match(r'^b([01xzXZ]+)\s+(\S+)$', line, re.IGNORECASE)
            if vec_m:
                val = vec_m.group(1)
                sig_id = vec_m.group(2)
                if sig_id in signals:
                    events.append((current_time, sig_id, val))

        return events

    def _build_cycles(self, events: list[tuple], signals: dict) -> list[dict]:
        """
        Group events by timestamp, find rising clock edges,
        and build a snapshot per clock cycle.
        """
        # Bucket events by timestamp
        by_time: dict[int, list] = {}
        for ts, sid, val in events:
            by_time.setdefault(ts, []).append((sid, val))

        # Find clock signal id
        clk_id = None
        for sid, info in signals.items():
            if info["name"].lower() in ("clk", "clock"):
                clk_id = sid
                break

        # Track current signal values
        current: dict[str, str] = {sid: "0" for sid in signals}
        prev_clk = "0"
        cycles: list[dict] = []
        cycle_num = 0

        for ts in sorted(by_time.keys()):
            changes = {}
            for sid, val in by_time[ts]:
                current[sid] = val
                changes[signals[sid]["name"]] = val

            # Rising clock edge?
            if clk_id and clk_id in dict(by_time[ts]):
                new_clk = current[clk_id]
                if prev_clk in ("0", "x", "z") and new_clk == "1":
                    # Snapshot all signals at this rising edge
                    snapshot = {
                        "cycle":     cycle_num,
                        "time_ps":   ts,
                        "changes":   changes,
                        "signals":   {}
                    }
                    for sid, info in signals.items():
                        snapshot["signals"][info["name"]] = current[sid]
                    cycles.append(snapshot)
                    cycle_num += 1
                prev_clk = new_clk
            elif not clk_id and by_time[ts]:
                # No clock found — emit one entry per unique timestamp
                snapshot = {
                    "cycle":   cycle_num,
                    "time_ps": ts,
                    "changes": changes,
                    "signals": {signals[sid]["name"]: current[sid] for sid in signals},
                }
                cycles.append(snapshot)
                cycle_num += 1

        return cycles


def _enrich_cycles(cycles: list[dict], fsm_key: str) -> list[dict]:
    """
    Add FSM-specific decoded information to each cycle snapshot:
    - state_name (human-readable)
    - state_idx  (for SVG highlight)
    - decoded outputs (red_led, motor_up, etc.)
    - pipeline stage annotation
    - ROM address interpretation
    """
    info = FSM_REGISTRY.get(fsm_key, {})
    state_names = info.get("state_names", {})
    state_idx   = info.get("state_idx", {})
    output_bits = info.get("output_bits", {})

    enriched = []
    prev_state = None

    for c in cycles:
        sigs = c["signals"]

        # state_code — may be 5-bit binary string
        raw_state = sigs.get("state_code", sigs.get("state_out", "00000"))
        # Normalise to 5-char binary (VCD may omit leading zeros)
        try:
            raw_state_norm = bin(int(raw_state, 2))[2:].zfill(5)
        except (ValueError, TypeError):
            raw_state_norm = "00000"

        sname = state_names.get(raw_state_norm, f"STATE_{raw_state_norm}")
        sidx  = state_idx.get(raw_state_norm, 0)

        # Decode output_action[15:0]
        raw_action = sigs.get("output_action", "0" * 16)
        decoded_outputs = {}
        try:
            action_int = int(raw_action, 2) if len(raw_action) > 1 else int(raw_action)
            for bit, sig_name in output_bits.items():
                decoded_outputs[sig_name] = int(bool(action_int & (1 << bit)))
        except (ValueError, TypeError):
            pass

        # Also pull direct output signals if output_action missing
        for bit, sig_name in output_bits.items():
            if sig_name not in decoded_outputs:
                v = sigs.get(sig_name, "0")
                decoded_outputs[sig_name] = 1 if v == "1" else 0

        # event_code
        raw_event = sigs.get("event_code", "0" * 10)
        try:
            event_int = int(raw_event, 2)
        except (ValueError, TypeError):
            event_int = 0

        # config_addr
        raw_addr = sigs.get("config_addr", "")
        try:
            addr_int = int(raw_addr, 2) if raw_addr else 0
        except (ValueError, TypeError):
            addr_int = 0

        # pipeline signals
        fsm_busy     = sigs.get("fsm_busy",     "0") == "1"
        output_valid = sigs.get("output_valid",  "0") == "1"
        timer_start  = sigs.get("timer_start_out", sigs.get("timer_start", "0")) == "1"
        reset        = sigs.get("reset", sigs.get("rst", "0")) == "1"

        # State transition detection
        state_changed = (prev_state is not None and raw_state_norm != prev_state)
        prev_state = raw_state_norm

        entry = {
            **c,
            "state_raw":      raw_state_norm,
            "state_name":     sname,
            "state_idx":      sidx,
            "state_changed":  state_changed,
            "event_code_int": event_int,
            "event_code_hex": f"0x{event_int:03X}",
            "config_addr_int":addr_int,
            "config_addr_hex":f"0x{addr_int:05X}",
            "fsm_busy":       fsm_busy,
            "output_valid":   output_valid,
            "timer_start":    timer_start,
            "reset":          reset,
            "decoded_outputs":decoded_outputs,
            # Pipeline stage annotation
            "pipeline_stage": (
                "Stage 1: Event Capture" if fsm_busy and event_int > 0 else
                "Stage 3: State Update"  if output_valid else
                "Idle"
            ),
        }
        enriched.append(entry)

    return enriched


# ─── Simulation runner (background thread) ───────────────────────────────────

def _run_simulation(run: SimRun):
    """Execute GHDL in a background thread and populate run.cycles."""
    fsm_key = run.fsm
    info = FSM_REGISTRY.get(fsm_key)
    if not info:
        run.error_msg = f"Unknown FSM key: {fsm_key}"
        run.status = "error"
        run._done_event.set()
        return

    cwd = PROJECT_ROOT
    vcd_path = VCD_DIR / info["vcd_name"]

    def log(msg: str):
        run.append_stdout(msg)

    run.status = "running"
    log(f"{'='*60}")
    log(f"  GHDL Simulation — {info['label']}")
    log(f"  Project root: {cwd}")
    log(f"  Timestamp: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    log(f"{'='*60}")

    # ── 1. Analyse source files ──────────────────────────────────────────────
    log("  [1/3] Analysing VHDL source files...")
    for fname in SRC_FILES:
        fpath = SRC_DIR / fname
        if not fpath.exists():
            log(f"    [SKIP] {fname} — not found at {fpath}")
            continue
        cmd = ["ghdl", "-a", GHDL_STD, str(fpath)]
        log(f"    $ {' '.join(cmd)}")
        rc, out, err = _run_cmd(cmd, cwd)
        if rc != 0:
            run.error_msg = f"Analysis failed: {fname}"
            run.status = "error"
            log(f"    ERROR: {err.strip()}")
            run._done_event.set()
            return
        log(f"    OK: {fname}")

    # ── 2. Analyse testbench ─────────────────────────────────────────────────
    tb_path = TB_DIR / info["tb_file"]
    if not tb_path.exists():
        run.error_msg = f"Testbench not found: {tb_path}"
        run.status = "error"
        log(f"    ERROR: {run.error_msg}")
        run._done_event.set()
        return

    log(f"\n  [2a] Analysing testbench: {info['tb_file']}")
    cmd = ["ghdl", "-a", GHDL_STD, str(tb_path)]
    log(f"    $ {' '.join(cmd)}")
    rc, out, err = _run_cmd(cmd, cwd)
    if rc != 0:
        run.error_msg = "Testbench analysis failed"
        run.status = "error"
        log(f"    ERROR: {err.strip()}")
        run._done_event.set()
        return
    log("    OK")

    # ── 3. Elaborate ─────────────────────────────────────────────────────────
    log(f"\n  [2b] Elaborating: {info['entity']}")
    cmd = ["ghdl", "-e", GHDL_STD, info["entity"]]
    log(f"    $ {' '.join(cmd)}")
    rc, out, err = _run_cmd(cmd, cwd)
    if rc != 0:
        run.error_msg = "Elaboration failed"
        run.status = "error"
        log(f"    ERROR: {err.strip()}")
        run._done_event.set()
        return
    log("    OK")

    # ── 4. Simulate → VCD ───────────────────────────────────────────────────
    log(f"\n  [3/3] Running simulation → {vcd_path.name}")
    cmd = ["ghdl", "-r", GHDL_STD, info["entity"], f"--vcd={str(vcd_path)}"]
    log(f"    $ {' '.join(cmd)}")
    rc, out, err = _run_cmd(cmd, cwd)

    combined = (out + "\n" + err).strip()
    for line in combined.splitlines():
        if not line.strip():
            continue
        # Strip GHDL prefix like "tb_traffic_light.vhd:42:(report note): "
        cleaned = re.sub(r'^[^:]+\.vhd:\d+:\([^)]+\):\s*', '', line)
        log(cleaned if cleaned else line)

    # rc != 0 is normal for some testbenches (assertion errors are expected)
    if vcd_path.exists():
        run.vcd_path = vcd_path
        log(f"\n  VCD written → {vcd_path} ({vcd_path.stat().st_size} bytes)")
    else:
        run.error_msg = "Simulation ran but no VCD was produced"
        run.status = "error"
        run._done_event.set()
        return

    # ── 5. Parse VCD ─────────────────────────────────────────────────────────
    log("\n  Parsing VCD waveform...")
    parser = VCDParser()
    raw_cycles = parser.parse(vcd_path)
    log(f"  Found {len(raw_cycles)} clock cycles in waveform")

    enriched = _enrich_cycles(raw_cycles, fsm_key)
    run.cycles = enriched

    log(f"\n{'='*60}")
    log(f"  DONE  passes={run.passes}  fails={run.fails}  cycles={len(enriched)}")
    log(f"{'='*60}")

    run.status = "done"
    run.finished = time.time()
    run._done_event.set()


# ─── API Routes ───────────────────────────────────────────────────────────────

@app.route("/api/status")
def api_status():
    ghdl_ok = _ghdl_available()
    ghdl_ver = ""
    if ghdl_ok:
        try:
            r = subprocess.run(["ghdl", "--version"], capture_output=True, text=True, timeout=5)
            ghdl_ver = r.stdout.splitlines()[0] if r.stdout else "unknown"
        except Exception:
            ghdl_ver = "available"

    return jsonify({
        "server":      "FSM Sim Server v1.0",
        "ghdl":        ghdl_ok,
        "ghdl_version":ghdl_ver,
        "project_root":str(PROJECT_ROOT),
        "src_exists":  SRC_DIR.exists(),
        "tb_exists":   TB_DIR.exists(),
        "src_files":   [f for f in SRC_FILES if (SRC_DIR / f).exists()],
        "fsm_list":    list(FSM_REGISTRY.keys()),
        "active_runs": len(_runs),
    })


@app.route("/api/fsm_list")
def api_fsm_list():
    return jsonify([
        {"key": k, "label": v["label"], "config_id": v["config_id"]}
        for k, v in FSM_REGISTRY.items()
    ])


@app.route("/api/run", methods=["POST"])
def api_run():
    """Launch a simulation run. Returns {run_id} immediately."""
    body = request.get_json(force=True, silent=True) or {}
    fsm_key = body.get("fsm", "traffic")

    if fsm_key not in FSM_REGISTRY:
        return jsonify({"error": f"Unknown FSM: {fsm_key}"}), 400

    if not _ghdl_available():
        return jsonify({
            "error": "GHDL not found on PATH. Install GHDL and ensure it is accessible.",
            "hint":  "sudo apt install ghdl  OR  brew install ghdl"
        }), 503

    run_id = str(uuid.uuid4())[:8]
    run = SimRun(run_id, fsm_key)

    with _runs_lock:
        _runs[run_id] = run

    thread = threading.Thread(target=_run_simulation, args=(run,), daemon=True)
    thread.start()

    return jsonify({"run_id": run_id, "fsm": fsm_key, "status": "pending"})


@app.route("/api/results/<run_id>")
def api_results(run_id: str):
    """Return full parsed results for a completed run."""
    with _runs_lock:
        run = _runs.get(run_id)
    if not run:
        return jsonify({"error": "Run not found"}), 404

    summary = run.to_summary()

    # Include cycles if done
    cycles_out = []
    if run.status == "done":
        # Trim signals dict to essential fields for payload size
        for c in run.cycles:
            cycles_out.append({
                "cycle":          c["cycle"],
                "time_ps":        c["time_ps"],
                "state_raw":      c["state_raw"],
                "state_name":     c["state_name"],
                "state_idx":      c["state_idx"],
                "state_changed":  c["state_changed"],
                "event_code_int": c["event_code_int"],
                "event_code_hex": c["event_code_hex"],
                "config_addr_hex":c["config_addr_hex"],
                "fsm_busy":       c["fsm_busy"],
                "output_valid":   c["output_valid"],
                "timer_start":    c["timer_start"],
                "reset":          c["reset"],
                "pipeline_stage": c["pipeline_stage"],
                "decoded_outputs":c["decoded_outputs"],
                "changes":        c.get("changes", {}),
            })

    return jsonify({
        **summary,
        "stdout": run.stdout_lines,
        "cycles": cycles_out,
    })


@app.route("/api/stream/<run_id>")
def api_stream(run_id: str):
    """
    Server-Sent Events stream.
    Sends log lines as they are produced, then cycle data when complete.
    """
    with _runs_lock:
        run = _runs.get(run_id)
    if not run:
        return jsonify({"error": "Run not found"}), 404

    def generate():
        sent = 0
        while True:
            with run._lock:
                lines = run.stdout_lines[sent:]
                status = run.status

            for line in lines:
                data = json.dumps({"type": "log", "line": line})
                yield f"data: {data}\n\n"
            sent += len(lines)

            if status in ("done", "error"):
                # Send final summary event
                summary = run.to_summary()
                data = json.dumps({"type": "done", "summary": summary})
                yield f"data: {data}\n\n"
                break

            time.sleep(0.15)

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={
            "Cache-Control":   "no-cache",
            "X-Accel-Buffering":"no",
        }
    )


@app.route("/api/cycle/<run_id>/<int:cycle_num>")
def api_cycle(run_id: str, cycle_num: int):
    """Return a single cycle snapshot by cycle number."""
    with _runs_lock:
        run = _runs.get(run_id)
    if not run:
        return jsonify({"error": "Run not found"}), 404
    if run.status != "done":
        return jsonify({"error": "Simulation not complete"}), 425
    if cycle_num >= len(run.cycles):
        return jsonify({"error": "Cycle out of range",
                        "max": len(run.cycles) - 1}), 404
    c = run.cycles[cycle_num]
    return jsonify(c)


@app.route("/api/reset", methods=["POST"])
def api_reset():
    """Clear all stored runs."""
    with _runs_lock:
        _runs.clear()
    return jsonify({"status": "cleared"})


@app.route("/api/vcd/<run_id>")
def api_vcd_download(run_id: str):
    """Return raw VCD file content for a completed run."""
    with _runs_lock:
        run = _runs.get(run_id)
    if not run or not run.vcd_path or not run.vcd_path.exists():
        return jsonify({"error": "VCD not available"}), 404
    return Response(
        run.vcd_path.read_text(errors="replace"),
        mimetype="text/plain",
        headers={"Content-Disposition": f"attachment; filename={run.vcd_path.name}"}
    )


# ─── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  FSM Backend Simulation Server")
    print("  BCS-307 Configurable FSM Project")
    print("=" * 60)
    print(f"  Project root : {PROJECT_ROOT}")
    print(f"  src/         : {SRC_DIR} ({'✓' if SRC_DIR.exists() else '✗ NOT FOUND'})")
    print(f"  tb/          : {TB_DIR}  ({'✓' if TB_DIR.exists() else '✗ NOT FOUND'})")
    print(f"  vcd_out/     : {VCD_DIR}")
    ghdl = _ghdl_available()
    print(f"  GHDL         : {'✓ available' if ghdl else '✗ not found — install ghdl'}")
    print()
    print("  Listening on http://localhost:5000")
    print("  API endpoints:")
    print("    GET  /api/status")
    print("    GET  /api/fsm_list")
    print("    POST /api/run          body: {\"fsm\": \"traffic\"}")
    print("    GET  /api/results/<id>")
    print("    GET  /api/stream/<id>  (SSE)")
    print("    GET  /api/cycle/<id>/<n>")
    print("    GET  /api/vcd/<id>")
    print("    POST /api/reset")
    print("=" * 60)
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
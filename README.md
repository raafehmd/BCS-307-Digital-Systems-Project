# BCS-307 Digital Systems Project
## Configurable FSM — VHDL Implementation

A configurable, ROM-driven Finite State Machine (FSM) core implemented in VHDL, with four application wrappers, a full testbench suite, and a Python simulation runner. The design supports multiple independent state machines sharing a single pipelined core, with each application's behaviour defined entirely by entries in the configuration ROM.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Source Files](#source-files)
- [Testbenches](#testbenches)
- [ROM Format](#rom-format)
- [Application Wrappers](#application-wrappers)
- [Error Handling Improvements](#error-handling-improvements)
- [Running Simulations](#running-simulations)
- [Tool Requirements](#tool-requirements)
- [VS Code Setup](#vs-code-setup)

---

## Project Structure

```
BCS-307-Digital-Systems-Project/
└── configurable_fsm/
    ├── run_sim.py                    # Python GUI simulation runner
    ├── src/                          # VHDL source files
    │   ├── config_rom.vhd            # Configuration ROM (all four apps)
    │   ├── generic_fsm.vhd           # Pipelined FSM core
    │   ├── elevator_wrapper.vhd      # Elevator controller
    │   ├── traffic_light_wrapper.vhd # Traffic light controller
    │   ├── serial_wrapper.vhd        # Serial protocol handler
    │   └── vending_wrapper.vhd       # Vending machine controller
    └── tb/                           # Testbench files
        ├── tb_fsm.vhd
        ├── tb_elevator.vhd
        ├── tb_traffic_light.vhd
        ├── tb_serial.vhd
        └── tb_vending.vhd
```

---

## Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │           Application Wrapper        │
  Physical          │  ┌──────────────┐  ┌─────────────┐  │   Physical
  Inputs  ─────────►│  │ Input Decoder│  │Output Encoder│ ├──► Outputs
                    │  └──────┬───────┘  └──────▲──────┘  │
                    │         │ event_code       │ output_action
                    │  ┌──────▼───────────────────────┐   │
                    │  │        generic_fsm (core)     │   │
                    │  │  Stage 1 → Stage 2 → Update   │   │
                    │  └──────────────┬───────────────┘   │
                    │                 │ config_addr        │
                    │  ┌──────────────▼───────────────┐   │
                    │  │         config_rom            │   │
                    │  │  [config_id & state & event]  │   │
                    │  └───────────────────────────────┘   │
                    └─────────────────────────────────────┘
```

The FSM core uses a **3-stage pipeline**:

| Stage | Process | Latency |
|---|---|---|
| Stage 1 | Event capture, `fsm_busy` assertion | 1 cycle |
| Stage 2 | ROM data capture | 1 cycle |
| State Update | State transition, output register | 1 cycle |

Total pipeline latency from event arrival to state update: **3 clock cycles**.

---

## Source Files

### `config_rom.vhd`

A 32,768-entry synchronous ROM storing transition tables for all four applications. The upper 2 bits of the 17-bit address select the application; the lower 15 bits encode the current state (5 bits) and event code (10 bits).

**Address format:**
```
[16:15] config_id  — selects application (00=traffic, 01=vending, 10=elevator, 11=serial)
[14:10] state      — current FSM state (5 bits, 0–31)
[9:0]   event      — bitmask event code (10 bits)
```

### `generic_fsm.vhd`

The pipelined FSM core. Shared by all four applications via the `config_id` port. Handles event capture, ROM address generation, state transitions, interrupt handling, and hold-state logic.

**Ports:**

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | IN | 1 | System clock |
| `reset` | IN | 1 | Synchronous reset, forces IDLE |
| `event_code` | IN | 10 | Bitmask event from application wrapper |
| `config_data` | IN | 32 | ROM output word |
| `config_id` | IN | 2 | Selects which ROM partition to use |
| `interrupt_event` | IN | 10 | Event code that triggers an interrupt return |
| `state_code` | OUT | 5 | Current FSM state |
| `output_action` | OUT | 16 | Output bitmask for application wrapper |
| `config_addr` | OUT | 17 | ROM address (combinatorial) |
| `output_valid` | OUT | 1 | Pulses when output_action is updated |
| `fsm_busy` | OUT | 1 | High for 1 cycle while pipeline is processing |
| `timer_start_out` | OUT | 1 | Timer start control from ROM |
| `timer_reset_out` | OUT | 1 | Timer reset control from ROM |
| `fsm_error` | OUT | 1 | Pulses on ROM miss or invalid transition |

---

## Testbenches

Each testbench is self-contained with a `check()` procedure, pass/fail counters, and a final results report. All `WAIT UNTIL` statements include timeout watchdogs to prevent silent false-passes.

| File | Entity | Tests | New Tests Added |
|---|---|---|---|
| `tb_fsm.vhd` | `tb_fsm` | 7 | Interrupt mechanism, ROM miss → `fsm_error` |
| `tb_elevator.vhd` | `tb_elevator` | 14 | Motor interlock check |
| `tb_traffic_light.vhd` | `tb_traffic_light` | 12 | Input conflict, fault on idle timer |
| `tb_serial.vhd` | `tb_serial` | 13 | Bad parity, idle pattern, frame error, reset gate |
| `tb_vending.vhd` | `tb_vending` | 12 | Out-of-stock display, coin edge detection |

**Expected results:** 59 passed, 0 failed across all five testbenches.

---

## ROM Format

Each 32-bit ROM word has the following layout:

```
Bit  31 30 29 | 28 27 26 25 24 | 23 ... 8 | 7 6 5 4 | 3           2           1            0
     reserved  | next_state(5)  | output(16)| reserved| timer_reset timer_start interrupt_en hold_state
```

| Field | Bits | Description |
|---|---|---|
| `next_state` | [28:24] | State to transition to on this event |
| `output_action` | [23:8] | Bitmask of outputs to assert |
| `timer_reset` | [3] | Assert timer reset signal |
| `timer_start` | [2] | Assert timer start signal |
| `interrupt_en` | [1] | If 1 and event matches interrupt_event, return to IDLE |
| `hold_state` | [0] | If 1, stay in current state (ignore next_state) |

The ROM uses the `rom_data()` helper function for all entries:
```vhdl
rom_data(next_state, output_action, hold_state, interrupt_en, timer_start, timer_reset)
```

---

## Application Wrappers

### Elevator (`elevator_wrapper.vhd`)

Controls an 11-floor elevator with door management, overload detection and emergency stop.

**Config ID:** `"10"` | **States:** IDLE, MOVE_UP, MOVE_DOWN, DOOR_OPEN, DOOR_CLOSE

| Input | Bit | Description |
|---|---|---|
| `floor_request[3:0]` | — | Target floor (1–11) |
| `door_sensor` | 4 | Door obstruction detected |
| `weight_sensor` | 5 | Overload condition |
| `emergency_btn` | 6 | Emergency stop (interrupt) |

| Output | Bit | Description |
|---|---|---|
| `motor_up` | 0 | Drive motor upward |
| `motor_down` | 1 | Drive motor downward |
| `door_open` | 2 | Open door actuator |
| `alarm_buzzer` | 3 | Overload alarm |
| `emergency_light` | — | Abort indicator (held for 10 ms) |
| `floor_display[3:0]` | — | Current floor number |
| `fsm_error_out` | — | FSM fault indicator |

---

### Traffic Light (`traffic_light_wrapper.vhd`)

Manages a standard road intersection with pedestrian crossing support.

**Config ID:** `"00"` | **States:** IDLE, RED, GREEN, YELLOW, PED_WAIT, PED_CROSS

| Input | Event | Description |
|---|---|---|
| `pedestrian_btn` | `0000000001` | Pedestrian crossing request (also interrupt) |
| `car_sensor` | `0000000010` | Vehicle detected |
| `timer_done` | `0000000100` | Phase timer expired |

| Output | Bit | Description |
|---|---|---|
| `red_led` | 0 | Red light |
| `yellow_led` | 1 | Yellow light |
| `green_led` | 2 | Green light |
| `ped_signal` | 3 | Pedestrian walk signal |
| `timer_start` | — | Start phase timer |
| `timer_reset` | — | Reset phase timer |
| `input_conflict` | — | Two inputs active simultaneously |
| `fault_err` | — | Timer fired while in IDLE |

---

### Vending Machine (`vending_wrapper.vhd`)

Coin-operated vending machine with item selection, dispensing and change return.

**Config ID:** `"01"` | **States:** IDLE, SELECT, COLLECT, DISPENSE, CHANGE

| Input | Event | Description |
|---|---|---|
| `coin_insert` | bit 0 | Coin detected (rising-edge only) |
| `selection_btn[1:0]` | bits [2:1] | Item selection buttons |
| `item_empty` | bit 3 | Selected item out of stock |
| `dispense_done` | bit 4 | Dispensing mechanism complete |
| `cancel_btn` | bit 5 | Cancel / refund (interrupt) |
| `change_done` | bit 6 | Change return mechanism complete |

| Output | Description |
|---|---|
| `dispense_motor` | Activate dispense mechanism |
| `change_return` | Activate change return mechanism |
| `display_msg[7:0]` | 8-bit display code (0xFF = out of stock) |

---

### Serial Protocol (`serial_wrapper.vhd`)

LSB-first 8-bit serial receiver with even parity checking.

**Config ID:** `"11"` | **States:** IDLE → START → RX_BIT0..7 → STOP → COMPLETE (12 states)

| Input | Description |
|---|---|
| `rx_data[7:0]` | Parallel input byte with parity bit |
| `rx_valid` | Rising edge = new bit available |
| `tx_ready` | Rising edge = transmitter ready to accept byte |

| Output | Description |
|---|---|
| `tx_data[7:0]` | Received byte (valid at SP_COMPLETE), idle = `0xFF` |
| `tx_enable` | Assert to transmit |
| `parity_err` | Bad parity detected (1-cycle pulse, gated on reset) |
| `frame_err` | Framing violation — `tx_ready` before transfer complete |
| `tx_data_valid` | `tx_data` holds valid received data |
| `state_out[4:0]` | Current FSM state for debugging |

---

## Error Handling Improvements

All five source files include defensive error handling not present in the original design. Full details are in `docs/error_handling_changes.md`.

**Summary of key additions:**

| Module | Improvement |
|---|---|
| `generic_fsm` | `fsm_error` port — pulses on ROM miss, reserved bits set, or out-of-range next_state |
| `elevator_wrapper` | Motor mutual-exclusion interlock, weight-sensor motor cut, door-open timeout |
| `elevator_wrapper` | Emergency light 10 ms hold, floor-latch guard against mid-journey changes |
| `vending_wrapper` | Coin rising-edge detection, collect-state idle timeout, out-of-stock display |
| `vending_wrapper` | Interrupt change-return coverage extended to SELECT and DISPENSE states |
| `traffic_light_wrapper` | Pedestrian interrupt enabled, input conflict output, fault on idle timer |
| `serial_wrapper` | `parity_err` reset gate, `frame_err` output, `0xFF` idle pattern, `tx_data_valid` |

---

## Running Simulations

### GUI Runner (recommended)

```bash
cd configurable_fsm
python run_sim.py
```

The GUI allows selecting individual testbenches or running all five in sequence. VCD waveform files are generated automatically and can be opened in GTKWave via the **Open Waveform** button.

### Manual GHDL (command line)

Files must be analysed in dependency order:

```bash
# 1. Analyse sources (order matters)
ghdl -a --std=08 src/config_rom.vhd
ghdl -a --std=08 src/generic_fsm.vhd
ghdl -a --std=08 src/traffic_light_wrapper.vhd
ghdl -a --std=08 src/vending_wrapper.vhd
ghdl -a --std=08 src/elevator_wrapper.vhd
ghdl -a --std=08 src/serial_wrapper.vhd

# 2. Analyse testbench
ghdl -a --std=08 tb/tb_elevator.vhd

# 3. Elaborate
ghdl -e --std=08 tb_elevator

# 4. Simulate with VCD output
ghdl -r --std=08 tb_elevator --vcd=tb_elevator.vcd
```

### View Waveforms

```bash
gtkwave tb_elevator.vcd
```

---

## Tool Requirements

| Tool | Version | Purpose |
|---|---|---|
| GHDL | ≥ 2.0 | VHDL analysis, elaboration, simulation |
| GTKWave | ≥ 3.3 | Waveform viewing (optional) |
| Python | ≥ 3.10 | GUI simulation runner |
| tkinter | stdlib | GUI (included with standard Python) |

**Install GHDL on Windows (MSYS2):**
```bash
pacman -S mingw-w64-x86_64-ghdl-llvm
```

**Install GHDL on Ubuntu/Debian:**
```bash
sudo apt install ghdl
```

---

## VS Code Setup

To resolve "No primary unit within library 'work'" warnings in the VHDL Language Server extension, create a `vhdl_ls.toml` file in the `configurable_fsm/` directory:

```toml
[libraries]
work.files = [
  "src/config_rom.vhd",
  "src/generic_fsm.vhd",
  "src/traffic_light_wrapper.vhd",
  "src/vending_wrapper.vhd",
  "src/elevator_wrapper.vhd",
  "src/serial_wrapper.vhd",
  "tb/tb_fsm.vhd",
  "tb/tb_elevator.vhd",
  "tb/tb_traffic_light.vhd",
  "tb/tb_serial.vhd",
  "tb/tb_vending.vhd"
]
```

> **Important:** `src/` files must always appear before `tb/` files. Dependencies must be listed before the files that use them. `config_rom.vhd` must be first.

---

## Simulation Results

| Testbench | Tests | Passed | Failed |
|---|---|---|---|
| FSM Core | 7 | 7 | 0 |
| Traffic Light | 12 | 12 | 0 |
| Vending Machine | 12 | 12 | 0 |
| Elevator | 14 | 14 | 0 |
| Serial Protocol | 13 | 13 | 0 |
| **Total** | **58** | **58** | **0** |
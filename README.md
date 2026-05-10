# BCS-307 Digital Systems Project
## Configurable FSM-Based Digital Controller in VHDL

### 🎯 Project Aim
Design and implement a **single, reusable hardware controller** that can be reconfigured to handle multiple different applications without changing the underlying VHDL code. This eliminates the need to write separate FSM implementations for each application.

### 🚀 What It Does
This project develops a **Generic, Table-Driven Finite State Machine (FSM)** that separates control logic from application-specific behavior. Instead of hard-coding separate FSMs for each task (traffic light, vending machine, etc.), we use a unified core with configuration tables that define how each application should behave.

**The Philosophy:** *Write Once, Use Forever.* A single VHDL core handles all state transitions and logic, while application-specific behavior is defined through ROM-based configuration tables.

### 💡 The Problem & Solution
Traditional FSM implementations are task-specific and redundant. Each new application requires rewriting the entire FSM logic. Our solution: **separate the control algorithm from the behavioral configuration**, enabling hardware reusability across diverse applications.

---

### 💡 Key Innovation: Configurable Architecture
The generic controller consists of:
* **Single Reusable Core:** One VHDL FSM engine that handles state transitions, outputs, and timing logic uniformly.
* **Table-Driven Configuration:** Each application is defined by lookup tables (ROM) that specify:
  - State transitions based on inputs
  - Output values for each state
  - Timing/delay parameters
* **Proven Across Applications:** The same core is validated on four completely different real-world use cases without code modification.
* **Efficiency Gains:** Dramatically reduces code redundancy, improves maintainability, and demonstrates hardware-software co-design principles.

### 🛠️ Validation Through Real-World Applications
The generic FSM core is tested and validated on four distinct scenarios, each representing different control requirements:
1.  **Traffic Light Control:** Time-based transitions—tests periodic/timer-driven behavior.
2.  **Vending Machine Controller:** Event-based transitions—tests input-driven state changes and credit management.
3.  **Elevator Control System:** Priority-based multi-state logic—tests complex state dependencies and user interaction.
4.  **Serial Communication Protocol:** Bit-stream processing—tests synchronized data handling and protocol-specific behavior.

All four applications run on the **same core hardware** with different configuration tables, proving true reconfigurability.

---

### 📂 Repository Structure
```text
BCS-307-Digital-Systems-Project/
├── Phase1/                  # Planning, Logic Diagrams, and Specifications
│   ├── All_FSM_Designs.docx
│   ├── Project_Setup_Glossary.docx
│   └── (Other Phase 1 Deliverables...)
├── Phase2/                  # VHDL Source Code & Verification
│   ├── src/                 # .vhdl source files (fsm_pkg, generic_fsm)
│   ├── sim/                 # Testbenches and Simulation Waveforms
│   └── constr/              # XDC physical constraints
└── README.md                # Project Overview (This file)
```

---

### 👥 The Team (CUD Students)
* **Aathif**
* **Heba**
* **Raafe**
* **Sara**

### 🛠️ Technology Stack
* **Language:** VHDL-2008
* **Tools:** Vivado 2023.2+, Visual Studio Code
* **Version Control:** Git & GitHub

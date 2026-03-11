# BCS-307 Digital Systems Project
## Configurable FSM-Based Digital Controller in VHDL

### 🚀 Project Overview
This project focuses on the design and implementation of a **Generic, Table-Driven Finite State Machine (FSM)**. Traditionally, FSMs are hard-coded for a single task (e.g., a traffic light). Our architecture breaks this limitation by separating the **Control Logic** from the **Behavioral Configuration**.

**The Philosophy:** *Write Once, Use Forever.* By utilizing a centralized VHDL core and application-specific configuration tables, we can switch the entire functionality of the hardware without modifying the underlying logic.

---

### 💡 Key Innovation: Configurable Architecture
* **Single Generic Core:** A single VHDL entity handles all state transitions and output logic.
* **Table-Driven Design:** Specific applications are defined by "Configuration Tables" (ROM-like structures) that dictate transitions and outputs.
* **Efficiency:** This approach leads to a significant reduction in code redundancy across different digital control systems.

### 🛠️ Targeted Applications
The controller will be validated across four distinct real-world scenarios:
1.  **Traffic Light Control System:** Time-based transitions for intersection management.
2.  **Vending Machine Controller:** Event-based transitions based on credit/input.
3.  **Elevator Control System:** Priority-based multi-state logic for floor navigation.
4.  **Serial Communication Protocol:** Bit-stream processing and state-dependent data handling.

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

---

### 👥 The Team (CUD Students)
* **Aathif** – System Architecture & FSM Design
* **Heba** – Application Requirements & Logic Flow
* **Wejd** – Configuration Logic & VHDL Optimization
* **Sarah** – QA, Testing & Risk Analysis
* **Raafe** – Project Management, Git Lead & Documentation

### 🛠️ Technology Stack
* **Language:** VHDL-2008
* **Tools:** Vivado 2023.2+, Visual Studio Code
* **Version Control:** Git & GitHub

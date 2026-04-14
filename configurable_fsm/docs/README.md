configurable_fsm/
├── src/
│   ├── generic_fsm.vhd           ← Core FSM entity (MAIN FOCUS)
│   ├── config_rom.vhd            ← Configuration ROM
│   ├── traffic_light_wrapper.vhd ← Application 1
│   ├── vending_wrapper.vhd       ← Application 2
│   ├── elevator_wrapper.vhd      ← Application 3
│   └── serial_wrapper.vhd        ← Application 4
├── tb/
│   ├── tb_generic_fsm.vhd        ← Test the core
│   ├── tb_traffic_light.vhd      ← Test app 1
│   └── ...
├── scripts/
│   ├── compile.sh                ← Compile commands
│   └── simulate.sh               ← Run simulation
└── docs/
    └── README.md                 ← Documentation
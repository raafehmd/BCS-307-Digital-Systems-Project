library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity config_rom is
  port (
    clk      : in std_logic;
    addr     : in std_logic_vector(16 downto 0);
    data_out : out std_logic_vector(31 downto 0)
  );
end entity config_rom;

architecture behavioral of config_rom is
  type rom_array is array (0 to 32767) of std_logic_vector(31 downto 0);

  -- Helper function to build ROM data word
  -- Allows flexible configuration of all control flags
  -- Format: [31:29]=unused, [28:24]=next_state, [23:8]=output_action,
  --         [7:4]=unused, [3]=timer_reset, [2]=timer_start, 
  --         [1]=interrupt_en, [0]=hold_state
  function rom_data(
    next_state    : std_logic_vector(4 downto 0);
    output_action : std_logic_vector(15 downto 0);
    hold_state    : std_logic;
    interrupt_en  : std_logic;
    timer_start   : std_logic;
    timer_reset   : std_logic
  ) return std_logic_vector is
  begin
    return "000" & next_state & output_action & "0000"
    & timer_reset & timer_start & interrupt_en & hold_state;
  end function rom_data;

  -- ========================================================================
  -- TRAFFIC LIGHT CONFIGURATION (Config ID = "00")
  -- ========================================================================

  -- Pre-calculated addresses for Traffic Light (Config ID = "00")
  -- Address format: config_id[16:15] & state[14:10] & event[9:0]
  -- For config_id = "00", addresses range from 0 to 32767
  
  -- State definitions
  constant STATE_IDLE    : std_logic_vector(4 downto 0) := "00000";
  constant STATE_RED     : std_logic_vector(4 downto 0) := "00001";
  constant STATE_GREEN   : std_logic_vector(4 downto 0) := "00010";
  constant STATE_YELLOW  : std_logic_vector(4 downto 0) := "00011";
  constant STATE_PED_WAIT: std_logic_vector(4 downto 0) := "00100";
  constant STATE_PED_CROSS:std_logic_vector(4 downto 0) := "00101";
  
  -- Event codes (10-bit bitmask integers matching wrapper encoding)
  -- Wrapper sends: bit0=pedestrian_btn, bit1=car_sensor, bit2=timer_done
  constant EVENT_PED_REQUEST  : integer := 1;   -- bit 0 = 0000000001
  constant EVENT_CAR_ARRIVAL  : integer := 2;   -- bit 1 = 0000000010
  constant EVENT_TIMER_EXPIRE : integer := 4;   -- bit 2 = 0000000100
  constant EVENT_INTERRUPT    : integer := 0;
  
  -- Output action codes (16-bit masks for traffic light signals)
  -- Wrapper decodes: bit0=red_led, bit1=yellow_led, bit2=green_led, bit3=ped_signal
  constant OUT_RED_ON      : std_logic_vector(15 downto 0) := x"0001";  -- bit0 = red
  constant OUT_YELLOW_ON   : std_logic_vector(15 downto 0) := x"0002";  -- bit1 = yellow
  constant OUT_GREEN_ON    : std_logic_vector(15 downto 0) := x"0004";  -- bit2 = green
  constant OUT_PED_WALK    : std_logic_vector(15 downto 0) := x"0009";  -- bit0+bit3 = red + ped_signal
  constant OUT_PED_DONT    : std_logic_vector(15 downto 0) := x"0001";  -- bit0 = red held, ped off

  constant traffic_rom : rom_array := (
  -- =========================================================================
  -- TRAFFIC LIGHT ROM (Config ID = "00")
  -- Safe for generic_fsm event-driven pipeline
  -- Uses explicit HOLD rows for ignored events
  -- =========================================================================

  -- IDLE (base 0)
  0    => rom_data(STATE_IDLE,      x"0000",      '1','0','0','0'),
  1    => rom_data(STATE_RED,       OUT_RED_ON,   '0','0','1','1'),
  2    => rom_data(STATE_RED,       OUT_RED_ON,   '0','0','1','1'),
  4    => rom_data(STATE_IDLE,      x"0000",      '1','0','0','0'),

  -- RED (base 1024)
  1024 => rom_data(STATE_RED,       OUT_RED_ON,   '1','0','0','0'),
  1025 => rom_data(STATE_PED_WAIT,  OUT_PED_DONT, '0','0','1','1'),
  1026 => rom_data(STATE_RED,       OUT_RED_ON,   '1','0','0','0'),
  1028 => rom_data(STATE_GREEN,     OUT_GREEN_ON, '0','0','1','1'),

  -- GREEN (base 2048)
  2048 => rom_data(STATE_GREEN,     OUT_GREEN_ON, '1','0','0','0'),
  2049 => rom_data(STATE_PED_WAIT,  OUT_PED_DONT, '0','0','1','1'),
  2050 => rom_data(STATE_GREEN,     OUT_GREEN_ON, '1','0','0','0'),
  2052 => rom_data(STATE_YELLOW,    OUT_YELLOW_ON,'0','0','1','1'),

  -- YELLOW (base 3072)
  3072 => rom_data(STATE_YELLOW,    OUT_YELLOW_ON,'1','0','0','0'),
  3073 => rom_data(STATE_YELLOW,    OUT_YELLOW_ON,'1','0','0','0'),
  3074 => rom_data(STATE_YELLOW,    OUT_YELLOW_ON,'1','0','0','0'),
  3076 => rom_data(STATE_RED,       OUT_RED_ON,   '0','0','1','1'),

  -- PED_WAIT (base 4096)
  4096 => rom_data(STATE_PED_WAIT,  OUT_PED_DONT, '1','0','0','0'),
  4097 => rom_data(STATE_PED_WAIT,  OUT_PED_DONT, '1','0','0','0'),
  4098 => rom_data(STATE_PED_WAIT,  OUT_PED_DONT, '1','0','0','0'),
  4100 => rom_data(STATE_PED_CROSS, OUT_PED_WALK, '0','0','1','1'),

  -- PED_CROSS (base 5120)
  5120 => rom_data(STATE_PED_CROSS, OUT_PED_WALK, '1','0','0','0'),
  5121 => rom_data(STATE_PED_CROSS, OUT_PED_WALK, '1','0','0','0'),
  5122 => rom_data(STATE_PED_CROSS, OUT_PED_WALK, '1','0','0','0'),
  5124 => rom_data(STATE_RED,       OUT_RED_ON,   '0','0','1','1'),

  others => (others => '0')
);
  -- ========================================================================
  -- VENDING MACHINE CONFIGURATION (Config ID = "01")
  --
  -- States (5-bit): IDLE=00000, SELECT=00001, COLLECT=00010,
  --                 DISPENSE=00011, CHANGE=00100
  --
  -- Event bitmasks (spec 5.2.3):
  --   [0]   coin_insert    (0x001)
  --   [2:1] selection_btn  (0x002 / 0x004 / 0x006)
  --   [3]   item_empty     (0x008)
  --   [4]   dispense_done  (0x010)
  --   [5]   cancel_btn     (0x020 = VM_INTERRUPT_EVENT)
  --   [6]   change_done    (0x040)
  --
  -- Output bit layout (spec 5.2.4 / 5.2.8):
  --   [0]   dispense_motor
  --   [1]   change_return
  --   [9:2] display_msg (8 bits)
  --
  -- Per-state outputs:
  --   IDLE     = 0x0000  (display 0x00)
  --   COLLECT  = 0x0004  (display 0x01)
  --   SELECT   = 0x0008  (display 0x02)
  --   DISPENSE = 0x000D  (dispense_motor=1, display 0x03)
  --   CHANGE   = 0x0012  (change_return=1, display 0x04)
  --
  -- interrupt_en=1 ONLY on VM_COLLECT rows (spec 5.2.6).
  -- Index = state_code * 1024 + event_bitmask
  -- ========================================================================

  constant VM_STATE_IDLE     : std_logic_vector(4 downto 0) := "00000";
  constant VM_STATE_SELECT   : std_logic_vector(4 downto 0) := "00001";
  constant VM_STATE_COLLECT  : std_logic_vector(4 downto 0) := "00010";
  constant VM_STATE_DISPENSE : std_logic_vector(4 downto 0) := "00011";
  constant VM_STATE_CHANGE   : std_logic_vector(4 downto 0) := "00100";

  constant VM_OUT_IDLE     : std_logic_vector(15 downto 0) := x"0000";
  constant VM_OUT_COLLECT  : std_logic_vector(15 downto 0) := x"0004";
  constant VM_OUT_SELECT   : std_logic_vector(15 downto 0) := x"0008";
  constant VM_OUT_DISPENSE : std_logic_vector(15 downto 0) := x"000D";
  constant VM_OUT_CHANGE   : std_logic_vector(15 downto 0) := x"0012";

  constant vending_rom : rom_array := (
    -- =========================================================================
    -- VENDING MACHINE ROM (Config ID = "01")
    -- Safe for generic_fsm event-driven pipeline
    -- Adds explicit HOLD rows for no-event and ignored events
    -- =========================================================================
  
    -- Event codes used:
    --   0   = no event
    --   1   = coin_insert
    --   2   = selection_btn = "01"
    --   4   = selection_btn = "10"
    --   6   = selection_btn = "11"
    --   8   = item_empty
    --   16  = dispense_done
    --   32  = cancel_btn
    --   64  = change_done
  
    -- IDLE (base 0)
    0   => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    1   => rom_data(VM_STATE_COLLECT, VM_OUT_COLLECT,  '0','0','0','0'),
    2   => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    4   => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    6   => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    8   => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    16  => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    32  => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
    64  => rom_data(VM_STATE_IDLE,    VM_OUT_IDLE,     '1','0','0','0'),
  
    -- SELECT (base 1024)
    1024 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '1','0','0','0'),
    1025 => rom_data(VM_STATE_COLLECT,  VM_OUT_COLLECT,  '0','0','0','0'),
    1026 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '0','0','0','0'),
    1028 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '1','0','0','0'),
    1030 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '1','0','0','0'),
    1032 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '0','0','0','0'),
    1040 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '1','0','0','0'),
    1056 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '1','0','0','0'),
    1088 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '1','0','0','0'),
  
    -- COLLECT (base 2048)
    2048 => rom_data(VM_STATE_COLLECT,  VM_OUT_COLLECT,  '1','0','0','0'),
    2049 => rom_data(VM_STATE_COLLECT,  VM_OUT_COLLECT,  '1','0','0','0'),
    2050 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '0','1','0','0'),
    2052 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '0','1','0','0'),
    2054 => rom_data(VM_STATE_SELECT,   VM_OUT_SELECT,   '0','1','0','0'),
    2056 => rom_data(VM_STATE_COLLECT,  VM_OUT_COLLECT,  '1','0','0','0'),
    2064 => rom_data(VM_STATE_COLLECT,  VM_OUT_COLLECT,  '1','0','0','0'),
    2080 => rom_data(VM_STATE_IDLE,     VM_OUT_IDLE,     '0','1','0','0'),
    2112 => rom_data(VM_STATE_COLLECT,  VM_OUT_COLLECT,  '1','0','0','0'),
  
    -- DISPENSE (base 3072)
    3072 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
    3073 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
    3074 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
    3076 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
    3078 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
    3080 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '0','0','0','0'),
    3088 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '0','0','0','0'),
    3104 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
    3136 => rom_data(VM_STATE_DISPENSE, VM_OUT_DISPENSE, '1','0','0','0'),
  
    -- CHANGE (base 4096)
    4096 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4097 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4098 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4100 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4102 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4104 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4112 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4128 => rom_data(VM_STATE_CHANGE,   VM_OUT_CHANGE,   '1','0','0','0'),
    4160 => rom_data(VM_STATE_IDLE,     VM_OUT_IDLE,     '0','0','0','0'),
  
    others => (others => '0')
  );

  -- ========================================================================
  -- ELEVATOR CONFIGURATION ROM (Config ID = "10")
  -- 
  -- Address Calculation: (Current_State_Code * 1024) + Event_Code
  -- Example: EL_MOVE_UP (State 1 * 1024) + arrived (Event 4) = 1028
  -- ========================================================================

  -- State Definitions
  constant EL_STATE_IDLE       : std_logic_vector(4 downto 0) := "00000";
  constant EL_STATE_MOVE_UP    : std_logic_vector(4 downto 0) := "00001";
  constant EL_STATE_MOVE_DOWN  : std_logic_vector(4 downto 0) := "00010";
  constant EL_STATE_DOOR_OPEN  : std_logic_vector(4 downto 0) := "00011";
  constant EL_STATE_DOOR_CLOSE : std_logic_vector(4 downto 0) := "00100";

  constant elevator_rom : rom_array := (
  -- -----------------------------------------------------------------------
  -- EL_IDLE Transitions  (state 0 * 1024 = base 0)
  -- -----------------------------------------------------------------------
  1 => rom_data(EL_STATE_MOVE_UP, x"0001", '0', '0', '0', '0'), -- go_up   (bit 0)
  2 => rom_data(EL_STATE_MOVE_DOWN, x"0002", '0', '0', '0', '0'), -- go_down (bit 1)
  4 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '0', '0', '0', '0'), -- arrived (bit 2) – defensive

  -- -----------------------------------------------------------------------
  -- EL_MOVE_UP Transitions  (state 1 * 1024 = base 1024)
  -- -----------------------------------------------------------------------
  -- no-event default (event=0): hold in MOVE_UP, keep motor_up active
  -- Prevents a pipeline-stall cycle from dropping the motor output or
  -- falling through to the 'others => 0' default (which would go to IDLE).
  1024 => rom_data(EL_STATE_MOVE_UP, x"0001", '1', '0', '0', '0'),

  -- arrived (bit 2, event=4):  floor reached → open door
  1028 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '0', '1', '0', '0'),
  -- weight_sensor (bit 5, event=32): overload → IDLE + alarm
  1056 => rom_data(EL_STATE_IDLE, x"0008", '0', '1', '0', '0'),
  -- emergency_btn (bit 6, event=64): → IDLE immediately (interrupt)
  1088 => rom_data(EL_STATE_IDLE, x"0000", '0', '1', '0', '0'),

  -- -----------------------------------------------------------------------
  -- EL_MOVE_DOWN Transitions  (state 2 * 1024 = base 2048)
  -- -----------------------------------------------------------------------
  -- no-event default (event=0): hold in MOVE_DOWN, keep motor_down active
  2048 => rom_data(EL_STATE_MOVE_DOWN, x"0002", '1', '0', '0', '0'),

  -- arrived (bit 2, event=4): floor reached → open door
  2052 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '0', '1', '0', '0'),
  -- weight_sensor (bit 5, event=32): overload → IDLE + alarm
  2080 => rom_data(EL_STATE_IDLE, x"0008", '0', '1', '0', '0'),
  -- emergency_btn (bit 6, event=64): → IDLE immediately (interrupt)
  2112 => rom_data(EL_STATE_IDLE, x"0000", '0', '1', '0', '0'),

  -- -----------------------------------------------------------------------
  -- EL_DOOR_OPEN Transitions  (state 3 * 1024 = base 3072)
  --
  -- CRITICAL: Address 3072 (event=0) MUST hold in DOOR_OPEN.
  -- When the input_resolver gates event_code to 0 (because fsm_busy='1'
  -- during a pipeline-stall cycle), the FSM still processes the no-event
  -- ROM lookup.  Without this entry the 'others=>0' default would decode
  -- next_state as "00000" = EL_IDLE and silently escape DOOR_OPEN.
  -- -----------------------------------------------------------------------

  -- no-event default (event=0): hold in DOOR_OPEN, keep door_open output
  3072 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '1', '0', '0', '0'),

  -- arrived (bit 2, event=4): spurious re-trigger guard – hold in DOOR_OPEN.
  -- This fires on the pipeline cycle when the FSM first enters DOOR_OPEN
  -- because stage-1 re-samples 'arrived' while current_state is still
  -- MOVE_UP.  interrupt_en='0': no interrupt check on a pure hold entry.
  3076 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '1', '0', '0', '0'),

  -- door_clear (bit 3, event=8): path clear → begin door-close sequence.
  -- interrupt_en='0': door_clear is a normal (non-interruptible) transition.
  3080 => rom_data(EL_STATE_IDLE, x"0000", '0', '0', '0', '0'), -- door_clear: close + go IDLE directly (no timer to exit DOOR_CLOSE)

  -- door_sensor (bit 4, event=16): obstruction detected → hold door open.
  -- FIX: was interrupt_en='1' which caused a false interrupt when both
  -- event_code_reg_p2 and interrupt_event_p2 were simultaneously "0000000000"
  -- after a pipeline flush.  Changed to interrupt_en='0' so the hold is
  -- unconditional; emergency is still handled by the dedicated entry below.
  3088 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '1', '0', '0', '0'),

  -- weight_sensor (bit 5, event=32): overload while door open → IDLE + alarm
  3104 => rom_data(EL_STATE_IDLE, x"0008", '0', '0', '0', '0'),

  -- emergency_btn (bit 6, event=64): → IDLE (highest resolver priority,
  -- so this entry is reached whenever emergency fires in DOOR_OPEN).
  -- interrupt_en='1' is harmless here because the event code equals
  -- EV_EMERGENCY so the interrupt path and the normal path both lead to IDLE.
  3136 => rom_data(EL_STATE_IDLE, x"0000", '0', '1', '0', '0'),

  -- -----------------------------------------------------------------------
  -- EL_DOOR_CLOSE Transitions  (state 4 * 1024 = base 4096)
  -- -----------------------------------------------------------------------
  -- no-event default (event=0): DOOR_CLOSE is a one-shot transient state.
  -- After the door_clear event fires and transitions here, the next cycle
  -- has no new event (door_clear may already be deasserted).  Auto-advance
  -- to IDLE so the cabin does not stall waiting for another event.
  4096 => rom_data(EL_STATE_IDLE, x"0000", '0', '0', '0', '0'),
  -- door_clear (bit 3, event=8): door fully closed → IDLE
  4104 => rom_data(EL_STATE_IDLE, x"0000", '0', '0', '0', '0'),
  -- door_sensor (bit 4, event=16): obstruction while closing → reopen door
  4112 => rom_data(EL_STATE_DOOR_OPEN, x"0004", '0', '0', '0', '0'),
  -- emergency_btn (bit 6, event=64): → IDLE
  4160 => rom_data(EL_STATE_IDLE, x"0000", '0', '1', '0', '0'),

  others => (others => '0')
  );

  -- ========================================================================
  -- Serial Protocol ROM (Config ID = "11")
  constant serial_rom : rom_array := (
  256   => rom_data("00001", x"0000", '0', '0', '0', '0'), -- SP_IDLE    + rx_valid -> SP_START
  1280  => rom_data("00010", x"0000", '0', '0', '0', '0'), -- SP_START   + rx_valid -> SP_RX_BIT0
  2304  => rom_data("00011", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT0 + rx_valid -> SP_RX_BIT1
  3328  => rom_data("00100", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT1 + rx_valid -> SP_RX_BIT2
  4352  => rom_data("00101", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT2 + rx_valid -> SP_RX_BIT3
  5376  => rom_data("00110", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT3 + rx_valid -> SP_RX_BIT4
  6400  => rom_data("00111", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT4 + rx_valid -> SP_RX_BIT5
  7424  => rom_data("01000", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT5 + rx_valid -> SP_RX_BIT6
  8448  => rom_data("01001", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT6 + rx_valid -> SP_RX_BIT7
  9472  => rom_data("01010", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT7 + rx_valid -> SP_STOP
  10496 => rom_data("01011", x"0100", '0', '1', '0', '0'), -- SP_STOP    + rx_valid -> SP_COMPLETE (tx_enable=1)
  11776 => rom_data("00000", x"0000", '0', '0', '0', '0'), -- SP_COMPLETE+ tx_ready -> SP_IDLE
  others => (others => '0')
  );

begin
  -- Combinational ROM read.
  -- generic_fsm.vhd pipeline_stage2 already registers config_data into
  -- config_data_p2.  A clocked (synchronous) read here would add a 3rd
  -- pipeline stage, causing state_update to consume stale all-zero data
  -- and the FSM would never advance past IDLE.  Combinational read gives
  -- the correct 2-cycle total latency the spec prescribes.
  read_process : process (addr)
    variable addr_int : integer;
  begin
    addr_int := to_integer(unsigned(addr(14 downto 0)));

    -- Decode config_id (upper 2 bits of address) to select ROM
    case addr(16 downto 15) is
      when "00" =>
        -- Traffic Light Config
        data_out <= traffic_rom(addr_int);

      when "01" =>
        -- Vending Machine Config
        data_out <= vending_rom(addr_int);

      when "10" =>
        -- Elevator Config
        data_out <= elevator_rom(addr_int);

      when "11" =>
        -- Serial Protocol Config
        data_out <= serial_rom(addr_int);

      when others =>
        -- Safety fallback
        data_out <= (others => '0');
    end case;
  end process read_process;

end architecture behavioral;

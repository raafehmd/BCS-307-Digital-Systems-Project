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

  -- Pre-calculated addresses for Traffic Light (Config ID = "00")
  -- Address format: config_id[16:15] & state[14:10] & event[9:0]
  -- For config_id = "00", addresses range from 0 to 32767

  -- State definitions
  constant STATE_IDLE      : std_logic_vector(4 downto 0) := "00000";
  constant STATE_RED       : std_logic_vector(4 downto 0) := "00001";
  constant STATE_GREEN     : std_logic_vector(4 downto 0) := "00010";
  constant STATE_YELLOW    : std_logic_vector(4 downto 0) := "00011";
  constant STATE_PED_WAIT  : std_logic_vector(4 downto 0) := "00100";
  constant STATE_PED_CROSS : std_logic_vector(4 downto 0) := "00101";

  -- Event codes
  constant EVENT_CAR_ARRIVAL  : integer := 1;
  constant EVENT_PED_REQUEST  : integer := 2;
  constant EVENT_TIMER_EXPIRE : integer := 3;
  constant EVENT_INTERRUPT    : integer := 0;

  -- Output action codes (16-bit masks for traffic light signals)
  constant OUT_RED_ON    : std_logic_vector(15 downto 0) := x"0001";
  constant OUT_GREEN_ON  : std_logic_vector(15 downto 0) := x"0002";
  constant OUT_YELLOW_ON : std_logic_vector(15 downto 0) := x"0004";
  constant OUT_PED_WALK  : std_logic_vector(15 downto 0) := x"0008";
  constant OUT_PED_DONT  : std_logic_vector(15 downto 0) := x"0010";

  -- Traffic Light ROM (Config ID = "00")
  constant traffic_rom : rom_array := (
  -- IDLE State: Wait for car or pedestrian
  -- Addr = 0x00000 (config_id=00, state=00000, event=0000)
  0 => rom_data(STATE_IDLE, OUT_RED_ON, '1', '0', '0', '0'),

  -- RED state, CAR_ARRIVAL event (addr = 0x00100 + 1)
  -- => Transition to GREEN with timer enabled
  257 => rom_data(STATE_GREEN, OUT_GREEN_ON, '0', '0', '1', '1'),

  -- RED state, PED_REQUEST event (addr = 0x00200 + 2)
  -- => Go to PED_WAIT state with hold (acknowledge request)
  514 => rom_data(STATE_PED_WAIT, OUT_PED_DONT, '0', '0', '0', '0'),

  -- RED state, TIMER_EXPIRE event (addr = 0x00300 + 3)
  -- => Stay in RED until event clears
  771 => rom_data(STATE_RED, OUT_RED_ON, '1', '0', '0', '0'),

  -- GREEN state, CAR_ARRIVAL event (addr = 0x08100 + 1)
  -- => Stay in GREEN with timer active
  2049 => rom_data(STATE_GREEN, OUT_GREEN_ON, '0', '0', '1', '1'),

  -- GREEN state, PED_REQUEST event (addr = 0x08200 + 2)
  -- => Move to YELLOW state to begin transition
  2306 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '0', '0', '1', '1'),

  -- GREEN state, TIMER_EXPIRE event (addr = 0x08300 + 3)
  -- => Transition to YELLOW (green time exhausted)
  2563 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '0', '0', '1', '1'),

  -- YELLOW state, CAR_ARRIVAL event (addr = 0x10100 + 1)
  -- => Stay in YELLOW (timer must expire first)
  4097 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '1', '0', '0', '0'),

  -- YELLOW state, PED_REQUEST event (addr = 0x10200 + 2)
  -- => Stay in YELLOW (non-blocking)
  4354 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '1', '0', '0', '0'),

  -- YELLOW state, TIMER_EXPIRE event (addr = 0x10300 + 3)
  -- => Return to RED after yellow timeout
  4611 => rom_data(STATE_RED, OUT_RED_ON, '0', '0', '1', '1'),

  -- PED_WAIT state, TIMER_EXPIRE event (addr = 0x18300 + 3)
  -- => Transition to PED_CROSS for pedestrian crossing
  6403 => rom_data(STATE_PED_CROSS, OUT_PED_WALK, '0', '0', '1', '1'),

  -- PED_CROSS state, TIMER_EXPIRE event (addr = 0x20300 + 3)
  -- => Return to IDLE after pedestrian crosses
  8195 => rom_data(STATE_IDLE, OUT_RED_ON, '0', '0', '0', '0'),

  -- Default entries (undefined states/events return 0 = hold state, no action)
  others => (others => '0')
  );

  -- Vending Machine ROM (Config ID = "01") - Placeholder
  -- To be populated with vending machine state transitions
  constant vending_rom : rom_array := (others => (others => '0'));

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
  -- Synchronous ROM read process
  -- On each rising clock edge, output the ROM data at the given address
  read_process : process (clk)
    variable addr_int : integer;
  begin
    if rising_edge(clk) then
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
    end if;
  end process read_process;

end architecture behavioral;
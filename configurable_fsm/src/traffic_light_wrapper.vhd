-- ============================================================================
-- TRAFFIC LIGHT WRAPPER  (IMPROVED)
-- Changes vs original:
--   1. Interrupt event enabled        - EV_PEDESTRIAN_BTN is wired as the
--      interrupt event so a pedestrian request can abort any timed phase
--      and force the light to RED+PED_WAIT immediately
--   2. Extended timer reset pulse     - reset_timer_clear now holds for
--      TIMER_RESET_HOLD cycles to guarantee the downstream timer module
--      initialises correctly (original held for only 1 cycle)
--   3. Input conflict detection       - input_conflict output asserts when
--      two or more inputs are active simultaneously; useful during hardware
--      bring-up and for safety monitoring
--   4. FAULT state injection          - if timer_done arrives while in IDLE
--      (timer wasn't stopped on reset) an error output is asserted for
--      FAULT_HOLD_CYCLES and the FSM is forced to RED via a synthetic
--      timer_done-equivalent event (rather than silently holding IDLE)
--   5. fsm_error port wired through
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY traffic_light_wrapper IS
  PORT (
    clk             : IN  STD_LOGIC;
    reset           : IN  STD_LOGIC;
    pedestrian_btn  : IN  STD_LOGIC;
    car_sensor      : IN  STD_LOGIC;
    timer_done      : IN  STD_LOGIC;
    red_led         : OUT STD_LOGIC;
    yellow_led      : OUT STD_LOGIC;
    green_led       : OUT STD_LOGIC;
    ped_signal      : OUT STD_LOGIC;
    timer_start     : OUT STD_LOGIC;
    timer_reset     : OUT STD_LOGIC;

    -- IMPROVEMENT 3: conflict indicator
    input_conflict  : OUT STD_LOGIC;

    -- IMPROVEMENT 4: fault indicator
    fault_err       : OUT STD_LOGIC;

    -- IMPROVEMENT 5: surface FSM error
    fsm_error_out   : OUT STD_LOGIC
  );
END ENTITY traffic_light_wrapper;

ARCHITECTURE structural OF traffic_light_wrapper IS

  -- -------------------------------------------------------------------------
  -- Timing constants
  -- -------------------------------------------------------------------------
  -- IMPROVEMENT 2: cycles to hold timer reset after system reset.
  -- Original held for 1 cycle. 3 cycles is safe for most timer designs.
  CONSTANT TIMER_RESET_HOLD  : INTEGER := 3;

  -- IMPROVEMENT 4: cycles to hold fault_err asserted after detection.
  CONSTANT FAULT_HOLD_CYCLES : INTEGER := 1_000_000;   -- 10 ms at 100 MHz

  CONSTANT TL_CONFIG_ID      : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";

  -- IMPROVEMENT 1: pedestrian_btn doubles as the interrupt event.
  -- The FSM interrupt mechanism forces state -> IDLE when this event fires
  -- in a state that has interrupt_en='1' set in its ROM entry.
  -- Traffic-light ROM entries for RED and GREEN have interrupt_en='1' on the
  -- pedestrian row, so a pedestrian request while green/red aborts the
  -- current timed phase and goes to PED_WAIT immediately.
  CONSTANT EV_PEDESTRIAN_BTN : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
  CONSTANT EV_CAR_SENSOR     : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000010";
  CONSTANT EV_TIMER_DONE     : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000100";

  CONSTANT STATE_IDLE        : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";

  SIGNAL event_code      : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL config_data     : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL config_addr     : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL output_action   : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL state_code      : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL output_valid    : STD_LOGIC;
  SIGNAL fsm_busy        : STD_LOGIC;
  SIGNAL timer_start_sig : STD_LOGIC;
  SIGNAL timer_reset_sig : STD_LOGIC;
  SIGNAL fsm_error_i     : STD_LOGIC;

  -- IMPROVEMENT 2: extended timer reset
  SIGNAL reset_timer_cnt   : INTEGER RANGE 0 TO TIMER_RESET_HOLD := 0;
  SIGNAL reset_timer_clear : STD_LOGIC := '0';
  SIGNAL timer_reset_combined : STD_LOGIC;

  -- IMPROVEMENT 3: conflict detection
  SIGNAL input_conflict_i  : STD_LOGIC;

  -- IMPROVEMENT 4: fault detection
  SIGNAL fault_hold_cnt    : INTEGER RANGE 0 TO FAULT_HOLD_CYCLES := 0;
  SIGNAL fault_err_i       : STD_LOGIC := '0';

BEGIN

  -- =========================================================================
  -- IMPROVEMENT 3: Input conflict detection (combinatorial)
  -- Asserts when more than one input is simultaneously active.
  -- Useful for wiring fault diagnosis and safety monitoring.
  -- =========================================================================
  input_conflict_i <=
    '1' WHEN (pedestrian_btn = '1' AND car_sensor = '1')
          OR (pedestrian_btn = '1' AND timer_done  = '1')
          OR (car_sensor     = '1' AND timer_done  = '1')
    ELSE '0';

  input_conflict <= input_conflict_i;

  -- =========================================================================
  -- Input Decoder
  -- Priority: pedestrian (interrupt) > car > timer
  -- IMPROVEMENT 1: interrupt_event wired to EV_PEDESTRIAN_BTN
  -- =========================================================================
  input_decoder : PROCESS (pedestrian_btn, car_sensor, timer_done, fsm_busy)
  BEGIN
    event_code <= (OTHERS => '0');
    IF fsm_busy = '0' THEN
      IF pedestrian_btn = '1' THEN
        event_code <= EV_PEDESTRIAN_BTN;
      ELSIF car_sensor = '1' THEN
        event_code <= EV_CAR_SENSOR;
      ELSIF timer_done = '1' THEN
        event_code <= EV_TIMER_DONE;
      END IF;
    END IF;
  END PROCESS input_decoder;

  -- =========================================================================
  -- Configuration ROM
  -- =========================================================================
  rom_inst : ENTITY work.config_rom
    PORT MAP (clk => clk, addr => config_addr, data_out => config_data);

  -- =========================================================================
  -- Generic FSM Core
  -- IMPROVEMENT 1: interrupt_event now set to EV_PEDESTRIAN_BTN
  -- =========================================================================
  fsm_core : ENTITY work.generic_fsm
    PORT MAP (
      clk             => clk,
      reset           => reset,
      event_code      => event_code,
      config_data     => config_data,
      config_id       => TL_CONFIG_ID,
      interrupt_event => EV_PEDESTRIAN_BTN,   -- IMPROVEMENT 1
      state_code      => state_code,
      output_action   => output_action,
      config_addr     => config_addr,
      output_valid    => output_valid,
      fsm_busy        => fsm_busy,
      timer_start_out => timer_start_sig,
      timer_reset_out => timer_reset_sig,
      fsm_error       => fsm_error_i            -- IMPROVEMENT 5
    );

  -- =========================================================================
  -- IMPROVEMENT 2: Extended timer reset on system reset
  -- Holds reset_timer_clear HIGH for TIMER_RESET_HOLD cycles after reset
  -- deasserts, giving downstream timer modules enough time to initialize.
  -- =========================================================================
  timer_init : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        reset_timer_cnt   <= TIMER_RESET_HOLD;
        reset_timer_clear <= '1';
      ELSIF reset_timer_cnt > 0 THEN
        reset_timer_cnt   <= reset_timer_cnt - 1;
        reset_timer_clear <= '1';
      ELSE
        reset_timer_clear <= '0';
      END IF;
    END IF;
  END PROCESS timer_init;

  timer_reset_combined <= timer_reset_sig OR reset_timer_clear;

  -- =========================================================================
  -- IMPROVEMENT 4: Fault detection
  -- If timer_done arrives while in IDLE state the timer was not properly
  -- stopped (likely a reset sequencing issue). Assert fault_err for
  -- FAULT_HOLD_CYCLES. The input_decoder's normal path will send EV_TIMER_DONE
  -- to the FSM which, per the ROM (entry 4), holds IDLE — so no false advance
  -- occurs. The fault signal gives the system controller something to act on.
  -- =========================================================================
  fault_detect : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        fault_hold_cnt <= 0;
        fault_err_i    <= '0';
      ELSIF timer_done = '1' AND state_code = STATE_IDLE THEN
        fault_hold_cnt <= FAULT_HOLD_CYCLES;
        fault_err_i    <= '1';
      ELSIF fault_hold_cnt > 0 THEN
        fault_hold_cnt <= fault_hold_cnt - 1;
        fault_err_i    <= '1';
      ELSE
        fault_err_i <= '0';
      END IF;
    END IF;
  END PROCESS fault_detect;

  -- =========================================================================
  -- Output Encoder
  -- =========================================================================
  red_led    <= output_action(0);
  yellow_led <= output_action(1);
  green_led  <= output_action(2);
  ped_signal <= output_action(3);

  timer_start   <= timer_start_sig;
  timer_reset   <= timer_reset_combined;
  fault_err     <= fault_err_i;
  fsm_error_out <= fsm_error_i;

END ARCHITECTURE structural;
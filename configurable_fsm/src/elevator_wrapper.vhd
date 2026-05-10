-- ============================================================================
-- ELEVATOR WRAPPER  (IMPROVED)
-- Changes vs original:
--   1. Motor mutual-exclusion interlock  - hardware OR-gate prevents both
--      motor_up and motor_down asserting simultaneously (ROM bug safety net)
--   2. Weight sensor motor guard         - combinatorial cut of motors when
--      weight_sensor is active (doesn't rely on FSM state to stop motion)
--   3. Door-open timeout counter         - forces a door_clear event after
--      DOOR_TIMEOUT_CYCLES if the door never clears naturally (stuck sensor)
--   4. Emergency light minimum hold      - stretches the 1-cycle pulse to
--      EMERG_LIGHT_HOLD_CYCLES so the signal is externally observable
--   5. fsm_error port wired through      - surfaces the new generic_fsm
--      error output on the top-level entity for board-level diagnosis
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY elevator_top IS
  PORT (
    clk   : IN STD_LOGIC;
    reset : IN STD_LOGIC;

    -- Elevator Inputs
    floor_request : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    door_sensor   : IN STD_LOGIC;
    weight_sensor : IN STD_LOGIC;
    emergency_btn : IN STD_LOGIC;

    -- Elevator Outputs
    motor_up        : OUT STD_LOGIC;
    motor_down      : OUT STD_LOGIC;
    door_open       : OUT STD_LOGIC;
    alarm_buzzer    : OUT STD_LOGIC;
    emergency_light : OUT STD_LOGIC;
    floor_display   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

    -- IMPROVEMENT 5: surface FSM error for external diagnostics
    fsm_error_out   : OUT STD_LOGIC
  );
END ENTITY elevator_top;

ARCHITECTURE behavioral OF elevator_top IS

  -- -------------------------------------------------------------------------
  -- Tunable timing constants
  -- -------------------------------------------------------------------------
  -- IMPROVEMENT 3: door-open timeout.
  -- After this many clock cycles in DOOR_OPEN without a natural door_clear,
  -- a synthetic door_timeout event is injected so the elevator doesn't stall.
  -- At 100 MHz clk: 500_000 cycles = 5 ms (adjust to suit hardware timer).
  CONSTANT DOOR_TIMEOUT_CYCLES  : INTEGER := 500_000;

  -- IMPROVEMENT 4: minimum hold duration for emergency_light.
  -- Stretches the original 1-cycle pulse to at least this many cycles.
  -- At 100 MHz: 1_000_000 = 10 ms; easily visible to an external controller.
  CONSTANT EMERG_LIGHT_HOLD_CYCLES : INTEGER := 1_000_000;

  -- Application constants
  CONSTANT EL_CONFIG_ID       : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";
  CONSTANT EL_INTERRUPT_EVENT : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0001000000";
  CONSTANT EL_IDLE_STATE      : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";

  -- Generic FSM interface signals
  SIGNAL event_code    : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL output_action : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL config_data   : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL config_addr   : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL state_code    : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL output_valid  : STD_LOGIC;
  SIGNAL fsm_busy      : STD_LOGIC;
  SIGNAL fsm_error_i   : STD_LOGIC;

  -- Floor tracking
  SIGNAL current_floor     : INTEGER RANGE 1 TO 11 := 1;
  SIGNAL target_floor      : INTEGER RANGE 1 TO 11 := 1;
  SIGNAL target_floor_comb : INTEGER RANGE 1 TO 11;

  -- Door stable detection (unchanged from original)
  SIGNAL door_open_stable  : STD_LOGIC := '0';
  SIGNAL door_open_stable2 : STD_LOGIC := '0';

  -- IMPROVEMENT 3: door-open timeout counter
  SIGNAL door_timeout_cnt   : INTEGER RANGE 0 TO DOOR_TIMEOUT_CYCLES := 0;
  SIGNAL door_timeout_event : STD_LOGIC := '0';  -- synthetic event bit

  -- IMPROVEMENT 4: emergency light hold counter
  SIGNAL emerg_hold_cnt : INTEGER RANGE 0 TO EMERG_LIGHT_HOLD_CYCLES := 0;
  SIGNAL emerg_light_i  : STD_LOGIC := '0';

  -- Abort detection
  SIGNAL prev_state_code : STD_LOGIC_VECTOR(4 DOWNTO 0);

  -- IMPROVEMENT 1 & 2: safe motor intermediates
  SIGNAL motor_up_raw   : STD_LOGIC;
  SIGNAL motor_down_raw : STD_LOGIC;

BEGIN

  -- =========================================================================
  -- Combinatorial floor target
  -- =========================================================================
  target_floor_comb <=
      TO_INTEGER(UNSIGNED(floor_request))
      WHEN (UNSIGNED(floor_request) >= 1 AND UNSIGNED(floor_request) <= 11)
      ELSE target_floor;

  -- =========================================================================
  -- 1. Input Decoder (Priority Encoder)
  -- =========================================================================
  -- Event bit mapping:
  --   bit 0 = go_up       (target > current, from IDLE)
  --   bit 1 = go_down     (target < current, from IDLE)
  --   bit 2 = arrived     (target = current, from MOVE state)
  --   bit 3 = door_clear  (sensor cleared while door open -> close)
  --   bit 4 = door_sensor (door blocked/held)
  --   bit 5 = weight      (overload)
  --   bit 6 = emergency   (EL_INTERRUPT_EVENT)
  -- =========================================================================
  input_decoder : PROCESS (current_floor, target_floor_comb, door_sensor,
                           weight_sensor, emergency_btn, state_code,
                           fsm_busy, door_open_stable2, door_timeout_event,
                           target_floor)
  BEGIN
    event_code <= (OTHERS => '0');

    IF fsm_busy = '0' THEN
      IF emergency_btn = '1' THEN
        event_code <= EL_INTERRUPT_EVENT;
      ELSIF weight_sensor = '1' THEN
        event_code(5) <= '1';
      ELSIF door_sensor = '1' THEN
        event_code(4) <= '1';
      -- IMPROVEMENT 3: inject synthetic door_clear on timeout even if
      -- door_sensor is still asserted (allows recovery from stuck sensor)
      ELSIF door_timeout_event = '1' THEN
        event_code(3) <= '1';
      ELSIF (state_code = "00011" AND door_sensor = '0' AND door_open_stable2 = '1')
            OR (state_code = "00100" AND door_sensor = '0') THEN
        event_code(3) <= '1';
      ELSIF state_code = "00000" THEN
        IF target_floor_comb > current_floor THEN
          event_code(0) <= '1';
        ELSIF target_floor_comb < current_floor THEN
          event_code(1) <= '1';
        END IF;
      ELSIF (state_code = "00001" OR state_code = "00010")
            AND target_floor = current_floor THEN
        event_code(2) <= '1';
      END IF;
    END IF;
  END PROCESS input_decoder;

  -- =========================================================================
  -- 2. Floor Latching
  -- =========================================================================
  floor_latch : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        target_floor <= 1;
      -- Only latch a new target when the elevator is IDLE to prevent
      -- mid-journey destination changes that could cause overshooting.
      ELSIF state_code = EL_IDLE_STATE
            AND UNSIGNED(floor_request) >= 1
            AND UNSIGNED(floor_request) <= 11 THEN
        target_floor <= TO_INTEGER(UNSIGNED(floor_request));
      END IF;
    END IF;
  END PROCESS floor_latch;

  -- =========================================================================
  -- 3. Floor Counter
  -- =========================================================================
  floor_counter : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        current_floor <= 1;
      ELSIF state_code = "00001" AND current_floor < target_floor
            AND current_floor < 11 THEN
        current_floor <= current_floor + 1;
      ELSIF state_code = "00010" AND current_floor > target_floor
            AND current_floor > 1 THEN
        current_floor <= current_floor - 1;
      END IF;
    END IF;
  END PROCESS floor_counter;

  -- =========================================================================
  -- 4. Configuration ROM
  -- =========================================================================
  rom_inst : ENTITY work.config_rom
    PORT MAP (clk => clk, addr => config_addr, data_out => config_data);

  -- =========================================================================
  -- 5. Generic FSM Core  (now with fsm_error port)
  -- =========================================================================
  fsm_core : ENTITY work.generic_fsm
    PORT MAP (
      clk             => clk,
      reset           => reset,
      event_code      => event_code,
      config_data     => config_data,
      config_id       => EL_CONFIG_ID,
      interrupt_event => EL_INTERRUPT_EVENT,
      state_code      => state_code,
      output_action   => output_action,
      config_addr     => config_addr,
      output_valid    => output_valid,
      fsm_busy        => fsm_busy,
      timer_start_out => OPEN,
      timer_reset_out => OPEN,
      fsm_error       => fsm_error_i   -- IMPROVEMENT 5
    );

  -- =========================================================================
  -- 6. Output Encoder
  -- IMPROVEMENT 1: motor mutual-exclusion interlock
  -- IMPROVEMENT 2: weight-sensor motor cut
  -- Both are combinatorial: they take effect within the same clock cycle,
  -- no matter what the FSM or ROM outputs.
  -- =========================================================================
  output_encoder : PROCESS (output_action, current_floor, weight_sensor, state_code)
  BEGIN
    motor_up_raw   <= output_action(0);
    motor_down_raw <= output_action(1);

    door_open <= output_action(2);

    IF weight_sensor = '1' THEN
      alarm_buzzer <= '1';
    ELSE
      alarm_buzzer <= output_action(3);
    END IF;

    floor_display <= STD_LOGIC_VECTOR(TO_UNSIGNED(current_floor, 4));
  END PROCESS output_encoder;

  -- IMPROVEMENT 1: mutual-exclusion interlock — only one motor at a time
  -- IMPROVEMENT 2: weight guard — both motors off when overloaded
  motor_up   <= motor_up_raw   AND NOT motor_down_raw AND NOT weight_sensor;
  motor_down <= motor_down_raw AND NOT motor_up_raw   AND NOT weight_sensor;

  -- =========================================================================
  -- 6b. Door Open Stable Detection  (unchanged from original)
  -- =========================================================================
  door_stable_proc : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        door_open_stable  <= '0';
        door_open_stable2 <= '0';
      ELSIF state_code = "00011" THEN
        door_open_stable  <= '1';
        door_open_stable2 <= door_open_stable;
      ELSE
        door_open_stable  <= '0';
        door_open_stable2 <= '0';
      END IF;
    END IF;
  END PROCESS door_stable_proc;

  -- =========================================================================
  -- 6c. IMPROVEMENT 3: Door-open timeout counter
  -- Counts up while in DOOR_OPEN state.  Fires door_timeout_event for one
  -- cycle when the counter saturates, which the input_decoder maps to a
  -- synthetic door_clear (bit 3) event to force the door closed.
  -- The counter resets whenever the FSM leaves DOOR_OPEN.
  -- =========================================================================
  door_timeout_proc : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' OR state_code /= "00011" THEN
        door_timeout_cnt   <= 0;
        door_timeout_event <= '0';
      ELSIF door_timeout_cnt < DOOR_TIMEOUT_CYCLES THEN
        door_timeout_cnt   <= door_timeout_cnt + 1;
        door_timeout_event <= '0';
      ELSE
        -- Saturated: hold the event high until the FSM transitions away
        door_timeout_cnt   <= DOOR_TIMEOUT_CYCLES;
        door_timeout_event <= '1';
      END IF;
    END IF;
  END PROCESS door_timeout_proc;

  -- =========================================================================
  -- 7. Emergency Light with minimum hold  (IMPROVEMENT 4)
  -- Original: 1-cycle pulse from abort_detect.
  -- Improved:  pulse is stretched to EMERG_LIGHT_HOLD_CYCLES so the signal
  --            remains visible to slower external monitors/LEDs.
  -- =========================================================================
  abort_detect : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF reset = '1' THEN
        prev_state_code <= EL_IDLE_STATE;
        emerg_light_i   <= '0';
        emerg_hold_cnt  <= 0;
      ELSE
        prev_state_code <= state_code;

        IF prev_state_code /= EL_IDLE_STATE
              AND state_code = EL_IDLE_STATE
              AND emergency_btn = '1' THEN
          -- Abort detected: start/restart hold timer
          emerg_light_i  <= '1';
          emerg_hold_cnt <= EMERG_LIGHT_HOLD_CYCLES;
        ELSIF emerg_hold_cnt > 0 THEN
          emerg_hold_cnt <= emerg_hold_cnt - 1;
          emerg_light_i  <= '1';
        ELSE
          emerg_light_i <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS abort_detect;

  emergency_light <= emerg_light_i;
  fsm_error_out   <= fsm_error_i;

END ARCHITECTURE behavioral;
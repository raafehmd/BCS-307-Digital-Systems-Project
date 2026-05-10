-- ============================================================================
-- VENDING MACHINE WRAPPER  (IMPROVED)
-- Changes vs original:
--   1. Rising-edge detection on coin_insert  - prevents a second coin event
--      being captured while fsm_busy briefly clears between pipeline stages
--   2. Collect-state idle timeout            - if no selection is made within
--      COLLECT_TIMEOUT_CYCLES the machine auto-cancels and returns change
--   3. Out-of-stock display code             - when item_empty fires, an
--      explicit OUT_OF_STOCK display_msg value (0xFF) is driven for
--      STOCK_MSG_HOLD_CYCLES so the user sees feedback
--   4. Wider interrupt change coverage       - int_change_pulse now also fires
--      when an interrupt aborts from SELECT or DISPENSE, not only COLLECT
--   5. fsm_error port wired through          - surfaces FSM core errors
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY vending_wrapper IS
  PORT (
    clk           : IN  STD_LOGIC;
    rst           : IN  STD_LOGIC;

    coin_insert   : IN  STD_LOGIC;
    selection_btn : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
    item_empty    : IN  STD_LOGIC;
    dispense_done : IN  STD_LOGIC;
    cancel_btn    : IN  STD_LOGIC;
    change_done   : IN  STD_LOGIC;

    dispense_motor : OUT STD_LOGIC;
    change_return  : OUT STD_LOGIC;
    display_msg    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

    state_code    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    fsm_busy      : OUT STD_LOGIC;
    output_valid  : OUT STD_LOGIC;

    -- IMPROVEMENT 5: surface FSM error
    fsm_error_out : OUT STD_LOGIC
  );
END ENTITY vending_wrapper;

ARCHITECTURE rtl OF vending_wrapper IS

  -- -------------------------------------------------------------------------
  -- Timing constants  (adjust to match clk frequency)
  -- -------------------------------------------------------------------------
  -- IMPROVEMENT 2: max cycles allowed in COLLECT with no selection.
  -- At 100 MHz: 500_000_000 = 5 seconds before auto-cancel.
  CONSTANT COLLECT_TIMEOUT_CYCLES : INTEGER := 500_000_000;

  -- IMPROVEMENT 3: how long the out-of-stock message is held on display_msg.
  -- At 100 MHz: 100_000_000 = 1 second.
  CONSTANT STOCK_MSG_HOLD_CYCLES  : INTEGER := 100_000_000;

  CONSTANT VM_CONFIG_ID       : STD_LOGIC_VECTOR(1 DOWNTO 0) := "01";
  CONSTANT VM_INTERRUPT_EVENT : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000100000";
  CONSTANT VM_STATE_IDLE      : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
  CONSTANT VM_STATE_SELECT    : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00001";
  CONSTANT VM_STATE_COLLECT   : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00010";
  CONSTANT VM_STATE_DISPENSE  : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00011";

  -- Out-of-stock display message (0xFF = all segments, easily distinctive)
  CONSTANT OUT_OF_STOCK_CODE  : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"FF";

  SIGNAL event_code      : STD_LOGIC_VECTOR(9 DOWNTO 0);
  SIGNAL config_addr     : STD_LOGIC_VECTOR(16 DOWNTO 0);
  SIGNAL config_data     : STD_LOGIC_VECTOR(31 DOWNTO 0);
  SIGNAL output_action   : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL state_code_i    : STD_LOGIC_VECTOR(4 DOWNTO 0);
  SIGNAL fsm_busy_i      : STD_LOGIC;
  SIGNAL output_valid_i  : STD_LOGIC;
  SIGNAL ts_unused       : STD_LOGIC;
  SIGNAL tr_unused       : STD_LOGIC;
  SIGNAL fsm_error_i     : STD_LOGIC;

  SIGNAL prev_state       : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
  SIGNAL int_change_pulse : STD_LOGIC := '0';

  -- IMPROVEMENT 1: coin edge detection
  SIGNAL coin_prev        : STD_LOGIC := '0';
  SIGNAL coin_rising      : STD_LOGIC;

  -- IMPROVEMENT 2: collect-state timeout
  SIGNAL collect_timer    : INTEGER RANGE 0 TO COLLECT_TIMEOUT_CYCLES := 0;
  SIGNAL collect_timeout  : STD_LOGIC := '0';

  -- IMPROVEMENT 3: out-of-stock message hold
  SIGNAL stock_msg_cnt    : INTEGER RANGE 0 TO STOCK_MSG_HOLD_CYCLES := 0;
  SIGNAL show_stock_msg   : STD_LOGIC := '0';

  -- Normal display value from output_action
  SIGNAL normal_display   : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

  -- =========================================================================
  -- IMPROVEMENT 1: edge detection for coin_insert
  -- coin_rising is HIGH for exactly 1 clock cycle per press, preventing the
  -- input_decoder from re-submitting a coin event on the cycle fsm_busy clears.
  -- =========================================================================
  coin_edge_proc : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF rst = '1' THEN
        coin_prev <= '0';
      ELSE
        coin_prev <= coin_insert;
      END IF;
    END IF;
  END PROCESS coin_edge_proc;

  coin_rising <= coin_insert AND NOT coin_prev;

  -- =========================================================================
  -- Input Decoder  (uses coin_rising instead of coin_insert)
  -- =========================================================================
  input_decoder : PROCESS (coin_rising, selection_btn, item_empty,
                           dispense_done, cancel_btn, change_done,
                           fsm_busy_i, collect_timeout)
  BEGIN
    event_code <= (OTHERS => '0');

    IF fsm_busy_i = '0' THEN
      IF cancel_btn = '1' THEN
        event_code <= VM_INTERRUPT_EVENT;
      -- IMPROVEMENT 2: inject cancel as interrupt on idle timeout
      ELSIF collect_timeout = '1' THEN
        event_code <= VM_INTERRUPT_EVENT;
      ELSIF change_done = '1' THEN
        event_code(6) <= '1';
      ELSIF dispense_done = '1' THEN
        event_code(4) <= '1';
      ELSIF item_empty = '1' THEN
        event_code(3) <= '1';
      ELSIF selection_btn /= "00" THEN
        event_code(2 DOWNTO 1) <= selection_btn;
      ELSIF coin_rising = '1' THEN          -- IMPROVEMENT 1: edge only
        event_code(0) <= '1';
      END IF;
    END IF;
  END PROCESS input_decoder;

  -- =========================================================================
  -- IMPROVEMENT 2: Collect-state idle timeout
  -- Counts while in COLLECT state. If no selection event is processed before
  -- the counter saturates, collect_timeout fires one interrupt-equivalent
  -- cycle to trigger the cancel path and return change to the customer.
  -- =========================================================================
  collect_timer_proc : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF rst = '1' OR state_code_i /= VM_STATE_COLLECT THEN
        collect_timer   <= 0;
        collect_timeout <= '0';
      ELSIF collect_timer < COLLECT_TIMEOUT_CYCLES THEN
        collect_timer   <= collect_timer + 1;
        collect_timeout <= '0';
      ELSE
        collect_timer   <= COLLECT_TIMEOUT_CYCLES;  -- saturate
        collect_timeout <= '1';
      END IF;
    END IF;
  END PROCESS collect_timer_proc;

  -- =========================================================================
  -- IMPROVEMENT 3: Out-of-stock message hold
  -- When item_empty fires and the FSM drives the display, we override
  -- display_msg with OUT_OF_STOCK_CODE for STOCK_MSG_HOLD_CYCLES cycles so
  -- the customer sees a clear "out of stock" indication rather than a brief
  -- blip before the display returns to IDLE.
  -- =========================================================================
  stock_msg_proc : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF rst = '1' THEN
        stock_msg_cnt  <= 0;
        show_stock_msg <= '0';
      ELSIF item_empty = '1' AND fsm_busy_i = '0' THEN
        -- item_empty event just captured: start/restart hold timer
        stock_msg_cnt  <= STOCK_MSG_HOLD_CYCLES;
        show_stock_msg <= '1';
      ELSIF stock_msg_cnt > 0 THEN
        stock_msg_cnt  <= stock_msg_cnt - 1;
        show_stock_msg <= '1';
      ELSE
        show_stock_msg <= '0';
      END IF;
    END IF;
  END PROCESS stock_msg_proc;

  -- =========================================================================
  -- IMPROVEMENT 4: Wider interrupt change-return coverage
  -- Original only fired change on COLLECT -> IDLE (cancel from COLLECT).
  -- Improved: also fires from SELECT and DISPENSE -> IDLE so change is
  -- always returned no matter which state an interrupt aborts from.
  -- =========================================================================
  interrupt_return_detect : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF rst = '1' THEN
        prev_state       <= (OTHERS => '0');
        int_change_pulse <= '0';
      ELSE
        int_change_pulse <= '0';

        -- IMPROVEMENT 4: cover SELECT and DISPENSE as well as COLLECT
        IF (prev_state = VM_STATE_COLLECT
            OR prev_state = VM_STATE_SELECT
            OR prev_state = VM_STATE_DISPENSE)
           AND state_code_i = VM_STATE_IDLE THEN
          int_change_pulse <= '1';
        END IF;

        prev_state <= state_code_i;
      END IF;
    END IF;
  END PROCESS interrupt_return_detect;

  -- =========================================================================
  -- Output assignments
  -- =========================================================================
  normal_display <= output_action(9 DOWNTO 2);

  dispense_motor <= output_action(0);
  change_return  <= output_action(1) OR int_change_pulse;

  -- IMPROVEMENT 3: override display with out-of-stock code when flagged
  display_msg <= OUT_OF_STOCK_CODE WHEN show_stock_msg = '1'
                 ELSE normal_display;

  state_code    <= state_code_i;
  fsm_busy      <= fsm_busy_i;
  output_valid  <= output_valid_i;
  fsm_error_out <= fsm_error_i;

  -- =========================================================================
  -- Subcomponent Instantiation
  -- =========================================================================
  rom_inst : ENTITY work.config_rom
    PORT MAP (clk => clk, addr => config_addr, data_out => config_data);

  fsm_core : ENTITY work.generic_fsm
    PORT MAP (
      clk             => clk,
      reset           => rst,
      event_code      => event_code,
      config_data     => config_data,
      config_id       => VM_CONFIG_ID,
      interrupt_event => VM_INTERRUPT_EVENT,
      state_code      => state_code_i,
      output_action   => output_action,
      config_addr     => config_addr,
      output_valid    => output_valid_i,
      fsm_busy        => fsm_busy_i,
      timer_start_out => ts_unused,
      timer_reset_out => tr_unused,
      fsm_error       => fsm_error_i    -- IMPROVEMENT 5
    );

END ARCHITECTURE rtl;
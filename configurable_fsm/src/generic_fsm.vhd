-- ============================================================================
-- Configurable FSM core  (IMPROVED)
-- Changes vs original:
--   1. Added fsm_error output port  - pulses for 1 cycle on any fault
--   2. ROM miss detection           - all-zero config_data while busy flags an error
--   3. Invalid next-state guard     - out-of-range next_state (>15) forces IDLE
--      and asserts fsm_error instead of silently corrupting state
--   4. Unused ROM bits [31:29],[7:4] documented as reserved; asserted in error
--      check so a partially-written ROM entry is also caught
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY generic_fsm IS
PORT (
    clk             : IN  STD_LOGIC;
    reset           : IN  STD_LOGIC;
    event_code      : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
    config_data     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
    config_id       : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
    interrupt_event : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
    state_code      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    output_action   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    config_addr     : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
    output_valid    : OUT STD_LOGIC;
    fsm_busy        : OUT STD_LOGIC;
    timer_start_out : OUT STD_LOGIC;
    timer_reset_out : OUT STD_LOGIC;
    -- IMPROVEMENT 1: observable error output
    -- Pulses HIGH for exactly 1 clock cycle when any of the following occur:
    --   a) ROM miss: config_data is all-zeros while the pipeline is processing
    --      an event (indicates an unmapped state/event combination in the ROM)
    --   b) Invalid next_state: ROM entry requests a transition to state > 15,
    --      which is outside the defined state space
    --   c) Reserved bits set: ROM bits [31:29] or [7:4] are non-zero,
    --      indicating a malformed ROM entry
    fsm_error       : OUT STD_LOGIC
);
END ENTITY generic_fsm;

ARCHITECTURE behavioral OF generic_fsm IS

    -- Maximum legal state index. States 0..MAX_STATE_INDEX are valid.
    -- Raise this constant if more states are added to any application.
    CONSTANT MAX_STATE_INDEX : INTEGER := 15;

    SIGNAL current_state     : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL event_code_reg    : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fsm_busy_i        : STD_LOGIC := '0';
    SIGNAL interrupt_event_i : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL output_action_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    -- Pipeline Stage 2 signals
    SIGNAL config_data_p2      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fsm_busy_p2         : STD_LOGIC := '0';
    SIGNAL interrupt_event_p2  : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL event_code_reg_p2   : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');

    -- IMPROVEMENT 2: internal error flag
    SIGNAL fsm_error_i : STD_LOGIC := '0';

BEGIN

    -- Combinatorial Address Construction
    config_addr <= config_id & current_state & event_code_reg;

    -- ========================================================================
    -- PIPELINE STAGE 1: Event Capture
    -- ========================================================================
    pipeline_stage1: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                event_code_reg    <= (OTHERS => '0');
                fsm_busy_i        <= '0';
                interrupt_event_i <= (OTHERS => '0');
            ELSE
                IF fsm_busy_i = '0' THEN
                    IF event_code /= "0000000000" THEN
                        event_code_reg    <= event_code;
                        interrupt_event_i <= interrupt_event;
                        fsm_busy_i        <= '1';
                    ELSE
                        event_code_reg    <= (OTHERS => '0');
                        interrupt_event_i <= (OTHERS => '0');
                        fsm_busy_i        <= '0';
                    END IF;
                ELSE
                    fsm_busy_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS pipeline_stage1;

    -- ========================================================================
    -- PIPELINE STAGE 2: ROM Data Capture
    -- ========================================================================
    pipeline_stage2: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                config_data_p2      <= (OTHERS => '0');
                fsm_busy_p2         <= '0';
                interrupt_event_p2  <= (OTHERS => '0');
                event_code_reg_p2   <= (OTHERS => '0');
            ELSE
                config_data_p2      <= config_data;
                fsm_busy_p2         <= fsm_busy_i;
                interrupt_event_p2  <= interrupt_event_i;
                event_code_reg_p2   <= event_code_reg;
            END IF;
        END IF;
    END PROCESS pipeline_stage2;

    -- ROM data format (32-bit word):
    -- [31:29] = reserved (should be 000)
    -- [28:24] = next_state (5 bits)
    -- [23:8]  = output_action (16 bits)
    -- [7:4]   = reserved (should be 0000)
    -- [3]     = timer_reset
    -- [2]     = timer_start
    -- [1]     = interrupt_en
    -- [0]     = hold_state

    -- ========================================================================
    -- STATE UPDATE + ERROR DETECTION PROCESS
    -- ========================================================================
    state_update: PROCESS(clk)
        VARIABLE next_state_v : STD_LOGIC_VECTOR(4 DOWNTO 0);
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                current_state     <= (OTHERS => '0');
                output_action_reg <= (OTHERS => '0');
                output_valid      <= '0';
                timer_start_out   <= '0';
                timer_reset_out   <= '0';
                fsm_error_i       <= '0';
            ELSE
                output_valid    <= '0';
                timer_start_out <= '0';
                timer_reset_out <= '0';
                fsm_error_i     <= '0';   -- default: no error

                IF fsm_busy_p2 = '1' THEN

                    -- --------------------------------------------------------
                    -- IMPROVEMENT 2: ROM miss detection
                    -- All-zero data on a real event means the ROM has no entry
                    -- for this (state, event) pair. Force IDLE and signal error.
                    -- --------------------------------------------------------
                    IF config_data_p2 = (config_data_p2'RANGE => '0') THEN
                        current_state     <= (OTHERS => '0');  -- safe fallback: IDLE
                        output_action_reg <= (OTHERS => '0');
                        fsm_error_i       <= '1';

                    -- --------------------------------------------------------
                    -- IMPROVEMENT 3: Reserved-bits check
                    -- Bits [31:29] or [7:4] non-zero indicate a malformed entry.
                    -- --------------------------------------------------------
                    ELSIF config_data_p2(31 DOWNTO 29) /= "000"
                       OR config_data_p2(7 DOWNTO 4)   /= "0000" THEN
                        current_state     <= (OTHERS => '0');
                        output_action_reg <= (OTHERS => '0');
                        fsm_error_i       <= '1';

                    ELSE
                        -- ROM data looks structurally valid
                        output_valid      <= '1';
                        output_action_reg <= config_data_p2(23 DOWNTO 8);
                        timer_start_out   <= config_data_p2(2);
                        timer_reset_out   <= config_data_p2(3);

                        next_state_v := config_data_p2(28 DOWNTO 24);

                        -- --------------------------------------------------------
                        -- IMPROVEMENT 4: Invalid next-state guard
                        -- Reject any next_state > MAX_STATE_INDEX to prevent
                        -- the FSM from jumping to an undefined state on a bad
                        -- ROM entry.  Error is flagged and machine returns to IDLE.
                        -- --------------------------------------------------------
                        IF to_integer(unsigned(next_state_v)) > MAX_STATE_INDEX THEN
                            current_state <= (OTHERS => '0');
                            fsm_error_i   <= '1';

                        -- Normal control priority: Interrupt > Hold > Normal
                        ELSIF config_data_p2(1) = '1'
                              AND event_code_reg_p2 = interrupt_event_p2 THEN
                            current_state <= (OTHERS => '0');  -- interrupt: force IDLE

                        ELSIF config_data_p2(0) = '1' THEN
                            NULL;  -- hold_state: stay in current state

                        ELSE
                            current_state <= next_state_v;  -- normal transition
                        END IF;

                    END IF; -- ROM data checks
                END IF; -- fsm_busy_p2
            END IF; -- reset
        END IF; -- rising_edge
    END PROCESS state_update;

    -- Output assignments
    state_code    <= current_state;
    output_action <= output_action_reg;
    fsm_busy      <= fsm_busy_i;
    fsm_error     <= fsm_error_i;

END ARCHITECTURE behavioral;
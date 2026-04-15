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
    timer_reset_out : OUT STD_LOGIC
);
END ENTITY generic_fsm;

ARCHITECTURE behavioral OF generic_fsm IS
    SIGNAL current_state     : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL event_code_reg    : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fsm_busy_i        : STD_LOGIC := '0';
    SIGNAL interrupt_event_i : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL output_action_reg : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    
    -- Pipeline Stage 2 signals (captured ROM data + control signals)
    SIGNAL config_data_p2      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fsm_busy_p2         : STD_LOGIC := '0';
    SIGNAL interrupt_event_p2  : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL event_code_reg_p2   : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');

BEGIN

    -- Combinatorial Address Construction (using current state and captured event code)
    -- Format: config_id[16:15] & current_state[14:10] & event_code_reg[9:0]
    config_addr <= config_id & current_state & event_code_reg;

    -- ========================================================================
    -- PIPELINE STAGE 1: Event Capture
    -- ========================================================================
    -- Captures incoming events and manages FSM busy signal
    -- Output: event_code_reg, interrupt_event_i, fsm_busy_i
    -- Latency: 1 clock cycle
    pipeline_stage1: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                event_code_reg    <= (OTHERS => '0');
                fsm_busy_i        <= '0';
                interrupt_event_i <= (OTHERS => '0');
            ELSE
                -- Capture new event only if FSM is not currently processing
                IF fsm_busy_i = '0' THEN
                    IF event_code /= "0000000000" THEN
                        -- New event detected: capture it and assert busy
                        event_code_reg    <= event_code;
                        interrupt_event_i <= interrupt_event;
                        fsm_busy_i        <= '1';
                    ELSE
                        -- No new event: maintain idle state
                        event_code_reg    <= (OTHERS => '0');
                        interrupt_event_i <= (OTHERS => '0');
                        fsm_busy_i        <= '0';
                    END IF;
                ELSE
                    -- FSM currently processing (fsm_busy_i = '1')
                    -- Keep signals stable for ROM lookup, clear busy on next cycle
                    fsm_busy_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS pipeline_stage1;

    -- ========================================================================
    -- PIPELINE STAGE 2: ROM Data Capture
    -- ========================================================================
    -- Captures ROM data and control signals from Stage 1
    -- Output: config_data_p2, fsm_busy_p2, event_code_reg_p2, interrupt_event_p2
    -- Latency: 1 clock cycle (total: 2 cycles from event arrival to state update)
    pipeline_stage2: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                config_data_p2      <= (OTHERS => '0');
                fsm_busy_p2         <= '0';
                interrupt_event_p2  <= (OTHERS => '0');
                event_code_reg_p2   <= (OTHERS => '0');
            ELSE
                -- Pipeline forwarding: capture Stage 1 outputs
                config_data_p2      <= config_data;
                fsm_busy_p2         <= fsm_busy_i;
                interrupt_event_p2  <= interrupt_event_i;
                event_code_reg_p2   <= event_code_reg;
            END IF;
        END IF;
    END PROCESS pipeline_stage2;

    -- ROM data format (32-bit word):
    -- [31:29] = unused (000)
    -- [28:24] = next_state (5 bits)
    -- [23:8]  = output_action (16 bits)
    -- [7:4]   = unused (0000)
    -- [3]     = timer_reset (control flag)
    -- [2]     = timer_start (control flag)
    -- [1]     = interrupt_en (control flag)
    -- [0]     = hold_state (control flag)

    -- ========================================================================
    -- STATE UPDATE PROCESS
    -- ========================================================================
    -- Uses fsm_busy_p2 to trigger state machine transition
    -- Implements 4-priority control: Reset > Interrupt > Hold > Normal
    state_update: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                -- External synchronous reset: force IDLE (00000)
                current_state     <= (OTHERS => '0');
                output_action_reg <= (OTHERS => '0');
                output_valid      <= '0';
                timer_start_out   <= '0';
                timer_reset_out   <= '0';
            ELSE
                -- Default outputs
                output_valid    <= '0';
                timer_start_out <= '0';
                timer_reset_out <= '0';

                -- State transition logic (executed when fsm_busy_p2 = '1')
                IF fsm_busy_p2 = '1' THEN
                    -- ROM data is valid in config_data_p2
                    output_valid      <= '1';
                    output_action_reg <= config_data_p2(23 DOWNTO 8);
                    timer_start_out   <= config_data_p2(2);
                    timer_reset_out   <= config_data_p2(3);

                    -- Control priority: Interrupt > Hold > Normal
                    -- Priority 1: Interrupt event forces return to IDLE
                    IF config_data_p2(1) = '1' AND event_code_reg_p2 = interrupt_event_p2 THEN
                        current_state <= (OTHERS => '0');  -- Force IDLE (S_IDLE = 00000)
                    -- Priority 2: Hold flag prevents state transition
                    ELSIF config_data_p2(0) = '1' THEN
                        -- Stay in current state (do not update current_state)
                        NULL;
                    -- Priority 3: Normal state transition
                    ELSE
                        current_state <= config_data_p2(28 DOWNTO 24);
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS state_update;

    -- Output assignments
    state_code    <= current_state;
    output_action <= output_action_reg;
    fsm_busy      <= fsm_busy_i;

END ARCHITECTURE behavioral;
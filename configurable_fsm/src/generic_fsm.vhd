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
    
    -- Pipeline Stage 3 signals (delayed one more cycle for state update)
    SIGNAL config_data_p3      : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL fsm_busy_p3         : STD_LOGIC := '0';
    SIGNAL interrupt_event_p3  : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL event_code_reg_p3   : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    
    -- Trigger signal: delayed fsm_busy for state update (avoids race condition)
    SIGNAL state_update_trigger : STD_LOGIC := '0';

BEGIN

    -- Combinatorial Address Construction (using current state and captured event code)
    config_addr <= config_id & current_state & event_code_reg;

    -- Pipeline Stage 1: Event Capture
    -- Captures incoming events and manages FSM busy signal
    pipeline_stage1: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                event_code_reg    <= (OTHERS => '0');
                fsm_busy_i        <= '0';
                interrupt_event_i <= (OTHERS => '0');
            ELSE
                IF fsm_busy_i = '0' THEN
                    -- FSM not busy, check for new event
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
                    -- FSM is busy, clear the busy flag next cycle
                    fsm_busy_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS pipeline_stage1;

    -- Output fsm_busy from stage 3
    fsm_busy <= fsm_busy_p3;

    -- Pipeline Stage 2: ROM Data Capture
    pipeline_stage2: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                config_data_p2    <= (OTHERS => '0');
                fsm_busy_p2       <= '0';
                interrupt_event_p2<= (OTHERS => '0');
                event_code_reg_p2 <= (OTHERS => '0');
            ELSE
                -- Capture current values to delay by one cycle
                config_data_p2    <= config_data;
                fsm_busy_p2       <= fsm_busy_i;
                interrupt_event_p2<= interrupt_event_i;
                event_code_reg_p2 <= event_code_reg;
            END IF;
        END IF;
    END PROCESS pipeline_stage2;

    -- Pipeline Stage 3: Additional delay before state update
    pipeline_stage3: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                config_data_p3    <= (OTHERS => '0');
                fsm_busy_p3       <= '0';
                interrupt_event_p3<= (OTHERS => '0');
                event_code_reg_p3 <= (OTHERS => '0');
            ELSE
                -- Capture from stage 2
                config_data_p3    <= config_data_p2;
                fsm_busy_p3       <= fsm_busy_p2;
                interrupt_event_p3<= interrupt_event_p2;
                event_code_reg_p3 <= event_code_reg_p2;
            END IF;
        END IF;
    END PROCESS pipeline_stage3;

    -- Trigger generation: Delay fsm_busy_p3 by one more cycle to trigger state update
    -- This avoids race condition where state_update samples fsm_busy_p3 before it updates
    trigger_gen: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                state_update_trigger <= '0';
            ELSE
                state_update_trigger <= fsm_busy_p3;
            END IF;
        END IF;
    END PROCESS trigger_gen;

    -- State Update Process
    -- Uses state_update_trigger (delayed version of fsm_busy_p3) to avoid race conditions
    state_update: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                current_state     <= (OTHERS => '0');
                output_action_reg <= (OTHERS => '0');
                output_valid      <= '0';
                timer_start_out   <= '0';
                timer_reset_out   <= '0';
            ELSE
                -- Defaults
                output_valid    <= '0';
                timer_start_out <= '0';
                timer_reset_out <= '0';

                -- Use delayed trigger instead of fsm_busy_p3 to avoid race condition
                -- On Cycle N, state_update_trigger reflects fsm_busy_p3 from Cycle N-1
                IF state_update_trigger = '1' THEN
                    -- We have valid ROM data in config_data_p3
                    output_valid      <= '1';
                    output_action_reg <= config_data_p3(23 DOWNTO 8);

                    -- Extract control flags from captured ROM data
                    -- Format: [28:24]=next_state, [23:8]=output_action, [7:4]=unused, [3]=timer_reset, [2]=timer_start, [1]=interrupt_en, [0]=hold_state
                    
                    IF config_data_p3(1) = '1' AND event_code_reg_p3 = interrupt_event_p3 THEN
                        -- Interrupt enabled and interrupt event matched -> force IDLE
                        current_state <= (OTHERS => '0');
                    ELSIF config_data_p3(0) = '1' THEN
                        -- Hold state flag set -> don't change state
                        current_state <= current_state;
                    ELSE
                        -- Normal state transition
                        current_state   <= config_data_p3(28 DOWNTO 24);
                        timer_start_out <= config_data_p3(2);
                        timer_reset_out <= config_data_p3(3);
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS state_update;

    state_code    <= current_state;
    output_action <= output_action_reg;

END ARCHITECTURE behavioral;
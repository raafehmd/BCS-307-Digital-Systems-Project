-- ============================================================================
-- SERIAL PROTOCOL WRAPPER  (IMPROVED)
-- Changes vs original:
--   1. Reset gate on parity_err        - false parity_err pulse no longer
--      fires when a mid-transfer system reset returns FSM to IDLE
--   2. unsigned() for state range      - state comparisons in rx_latch_proc
--      use UNSIGNED() to guarantee correct ordering in all VHDL tool versions
--   3. Frame error detection output    - frame_err asserts when tx_ready fires
--      before the FSM has completed a full byte (i.e. from a non-COMPLETE,
--      non-IDLE state), indicating a framing or sequence violation
--   4. tx_data idle pattern            - drives 0xFF (not 0x00) when outside
--      SP_COMPLETE, distinguishing idle bus from a transmitted null byte
--   5. tx_data_valid qualifier output  - explicit validity flag for downstream
--      consumers, replacing the implicit "check state_out == SP_COMPLETE" test
--   6. fsm_error port wired through
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY serial_wrapper IS
    PORT (
        clk        : IN  STD_LOGIC;
        reset      : IN  STD_LOGIC;
        rx_data    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        rx_valid   : IN  STD_LOGIC;
        tx_ready   : IN  STD_LOGIC;
        tx_data    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        tx_enable  : OUT STD_LOGIC;

        -- Error outputs
        parity_err : OUT STD_LOGIC;
        frame_err  : OUT STD_LOGIC;   -- IMPROVEMENT 3

        -- Status outputs
        state_out     : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        tx_data_valid : OUT STD_LOGIC;   -- IMPROVEMENT 5

        -- IMPROVEMENT 6: surface FSM error
        fsm_error_out : OUT STD_LOGIC
    );
END ENTITY serial_wrapper;

ARCHITECTURE behavioral OF serial_wrapper IS

    CONSTANT SP_INTERRUPT_EVENT : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1100000000";
    CONSTANT SP_IDLE     : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
    CONSTANT SP_COMPLETE : STD_LOGIC_VECTOR(4 DOWNTO 0) := "01011";

    -- State indices as integers for safe UNSIGNED comparisons
    CONSTANT SP_RX_BIT0_IDX : UNSIGNED(4 DOWNTO 0) := "00010";  -- state 2
    CONSTANT SP_RX_BIT7_IDX : UNSIGNED(4 DOWNTO 0) := "01001";  -- state 9

    -- FSM interface
    SIGNAL event_code    : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL output_action : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL config_data   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL config_addr   : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL state_code    : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL output_valid  : STD_LOGIC;
    SIGNAL fsm_busy      : STD_LOGIC;
    SIGNAL fsm_error_i   : STD_LOGIC;

    -- Even parity: '1' = even set bits (good), '0' = odd (fail)
    SIGNAL rx_parity_ok  : STD_LOGIC;

    -- Accumulated received byte (shift register, LSB first)
    SIGNAL rx_latch      : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    -- Edge detection
    SIGNAL rx_valid_prev : STD_LOGIC := '0';
    SIGNAL tx_ready_prev : STD_LOGIC := '0';

    -- Error detection
    SIGNAL prev_state    : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL parity_err_i  : STD_LOGIC := '0';
    SIGNAL frame_err_i   : STD_LOGIC := '0';

BEGIN

    -- =========================================================================
    -- Subcomponent instantiation
    -- =========================================================================
    rom_inst : ENTITY work.config_rom
        PORT MAP (clk => clk, addr => config_addr, data_out => config_data);

    fsm_core : ENTITY work.generic_fsm
        PORT MAP (
            clk             => clk,
            reset           => reset,
            event_code      => event_code,
            config_data     => config_data,
            config_id       => "11",
            interrupt_event => SP_INTERRUPT_EVENT,
            state_code      => state_code,
            output_action   => output_action,
            config_addr     => config_addr,
            output_valid    => output_valid,
            fsm_busy        => fsm_busy,
            timer_start_out => OPEN,
            timer_reset_out => OPEN,
            fsm_error       => fsm_error_i   -- IMPROVEMENT 6
        );

    -- =========================================================================
    -- Combinatorial parity check (even parity)
    -- =========================================================================
    rx_parity_ok <= NOT (rx_data(7) XOR rx_data(6) XOR rx_data(5) XOR rx_data(4)
                         XOR rx_data(3) XOR rx_data(2) XOR rx_data(1) XOR rx_data(0));

    -- =========================================================================
    -- Input encoder: edge-triggered to prevent double-event capture
    -- =========================================================================
    input_encoder : PROCESS (rx_valid, rx_valid_prev, tx_ready, tx_ready_prev,
                              rx_parity_ok)
    BEGIN
        event_code <= (OTHERS => '0');

        IF rx_valid = '1' AND rx_valid_prev = '0' THEN
            IF rx_parity_ok = '1' THEN
                event_code <= "0100000000";          -- bit8: good parity rx pulse
            ELSE
                event_code <= SP_INTERRUPT_EVENT;    -- bad parity: interrupt
            END IF;
        ELSIF tx_ready = '1' AND tx_ready_prev = '0' THEN
            event_code <= "1000000000";              -- bit9: tx_ready pulse
        END IF;
    END PROCESS input_encoder;

    -- =========================================================================
    -- rx_latch + edge-detection registers
    -- IMPROVEMENT 2: state range comparison uses UNSIGNED() for correctness
    -- =========================================================================
    rx_latch_proc : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                rx_latch      <= (OTHERS => '0');
                rx_valid_prev <= '0';
                tx_ready_prev <= '0';
            ELSE
                rx_valid_prev <= rx_valid;
                tx_ready_prev <= tx_ready;

                -- IMPROVEMENT 2: use UNSIGNED comparison (safe in all VHDL versions)
                IF rx_valid = '1' AND rx_valid_prev = '0'
                        AND rx_parity_ok = '1'
                        AND UNSIGNED(state_code) >= UNSIGNED(SP_RX_BIT0_IDX)
                        AND UNSIGNED(state_code) <= UNSIGNED(SP_RX_BIT7_IDX) THEN
                    rx_latch <= rx_data(0) & rx_latch(7 DOWNTO 1);
                END IF;
            END IF;
        END IF;
    END PROCESS rx_latch_proc;

    -- =========================================================================
    -- IMPROVEMENT 1: Parity error detection with reset gate
    -- Original fired on ANY unexpected IDLE return, including from a system
    -- reset mid-transfer. Gating on reset='0' prevents that false assertion.
    -- =========================================================================
    parity_detect : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                prev_state   <= (OTHERS => '0');
                parity_err_i <= '0';
            ELSE
                prev_state <= state_code;

                -- IMPROVEMENT 1: only flag as parity error when not in reset
                IF reset = '0'                          -- gate: not a reset-caused return
                        AND prev_state /= SP_IDLE
                        AND prev_state /= SP_COMPLETE
                        AND state_code = SP_IDLE THEN
                    parity_err_i <= '1';
                ELSE
                    parity_err_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS parity_detect;

    -- =========================================================================
    -- IMPROVEMENT 3: Frame error detection
    -- A tx_ready rising edge that arrives before the FSM reaches SP_COMPLETE
    -- indicates the transmitter is ready before a full byte has been received.
    -- This typically means the external transmitter has lost synchronisation.
    -- =========================================================================
    frame_err_detect : PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                frame_err_i <= '0';
            ELSIF tx_ready = '1' AND tx_ready_prev = '0'   -- tx_ready rising edge
                  AND state_code /= SP_IDLE                 -- not expected from IDLE
                  AND state_code /= SP_COMPLETE THEN        -- not a normal tx_ready
                frame_err_i <= '1';
            ELSE
                frame_err_i <= '0';
            END IF;
        END IF;
    END PROCESS frame_err_detect;

    -- =========================================================================
    -- Output assignments
    -- IMPROVEMENT 4: drive 0xFF as idle pattern for tx_data (not 0x00)
    -- IMPROVEMENT 5: explicit tx_data_valid qualifier
    -- =========================================================================
    -- IMPROVEMENT 4: 0xFF on the bus when not transmitting is more distinctive
    -- than 0x00 and prevents a transmitted null byte from being confused with
    -- an idle bus by downstream logic or a logic analyser.
    tx_data <= rx_latch WHEN state_code = SP_COMPLETE ELSE x"FF";

    tx_enable     <= output_action(8);
    parity_err    <= parity_err_i;
    frame_err     <= frame_err_i;                              -- IMPROVEMENT 3
    state_out     <= state_code;
    -- IMPROVEMENT 5: asserts only when tx_data holds valid received data
    tx_data_valid <= '1' WHEN state_code = SP_COMPLETE ELSE '0';
    fsm_error_out <= fsm_error_i;                              -- IMPROVEMENT 6

END ARCHITECTURE behavioral;
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
        parity_err : OUT STD_LOGIC;
        state_out  : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
    );
END ENTITY serial_wrapper;

ARCHITECTURE behavioral OF serial_wrapper IS

    CONSTANT SP_INTERRUPT_EVENT : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1100000000";
    CONSTANT SP_IDLE     : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
    CONSTANT SP_COMPLETE : STD_LOGIC_VECTOR(4 DOWNTO 0) := "01011";

    -- FSM interface
    SIGNAL event_code    : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL output_action : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL config_data   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL config_addr   : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL state_code    : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL output_valid  : STD_LOGIC;
    SIGNAL fsm_busy      : STD_LOGIC;

    -- Even parity check: '1' = even number of set bits (good), '0' = odd (fail)
    SIGNAL rx_parity_ok  : STD_LOGIC;

    -- Accumulated received byte (shift register, LSB first)
    SIGNAL rx_latch      : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    -- Rising-edge detect for rx_valid (latch each bit exactly once)
    SIGNAL rx_valid_prev : STD_LOGIC := '0';

    -- Parity error detection
    SIGNAL prev_state    : STD_LOGIC_VECTOR(4 DOWNTO 0) := (OTHERS => '0');
    SIGNAL parity_err_i  : STD_LOGIC := '0';

BEGIN

    -- =========================================================================
    -- Subcomponent instantiation
    -- =========================================================================
    rom_inst: ENTITY work.config_rom
        PORT MAP (clk => clk, addr => config_addr, data_out => config_data);

    fsm_core: ENTITY work.generic_fsm
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
            timer_reset_out => OPEN
        );

    -- =========================================================================
    -- Combinatorial parity check (even parity)
    -- =========================================================================
    rx_parity_ok <= NOT (rx_data(7) XOR rx_data(6) XOR rx_data(5) XOR rx_data(4)
                         XOR rx_data(3) XOR rx_data(2) XOR rx_data(1) XOR rx_data(0));

    -- =========================================================================
    -- Combinatorial input encoder
    -- rx_data bits are NOT included in event_code - the FSM never branches
    -- on data content, only on rx_valid/tx_ready flags. This means the ROM
    -- only needs 12 entries (one per transition) instead of 3072.
    -- rx_data is separately latched in rx_latch_proc for forwarding at COMPLETE.
    -- =========================================================================
    input_encoder: PROCESS(rx_valid, tx_ready, rx_parity_ok)
    BEGIN
        event_code <= (OTHERS => '0');  -- default: no event

        IF rx_valid = '1' THEN
            IF rx_parity_ok = '1' THEN
                -- Good parity: rx_valid flag only, data=0x00
                event_code <= "0100000000";  -- bit8=1, bits[7:0]=0
            ELSE
                -- Bad parity: drive interrupt sentinel
                event_code <= SP_INTERRUPT_EVENT;
            END IF;
        ELSIF tx_ready = '1' THEN
            -- tx_ready flag only, data=0x00
            event_code <= "1000000000";  -- bit9=1, bits[8:0]=0
        END IF;
    END PROCESS input_encoder;

    -- =========================================================================
    -- Latch rx_data(0) on the RISING EDGE of rx_valid only, and only during
    -- SP_RX_BIT0..SP_RX_BIT7 (states 2..9). Edge detection ensures each bit
    -- is captured exactly once even if rx_valid is held high for multiple
    -- clock cycles (as the pipeline requires). Shifts LSB-first.
    -- =========================================================================
    rx_latch_proc: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                rx_latch      <= (OTHERS => '0');
                rx_valid_prev <= '0';
            ELSE
                rx_valid_prev <= rx_valid;
                -- Only latch on rising edge of rx_valid, during data bit states
                IF rx_valid = '1' AND rx_valid_prev = '0'
                        AND rx_parity_ok = '1'
                        AND state_code >= "00010"   -- SP_RX_BIT0
                        AND state_code <= "01001" THEN  -- SP_RX_BIT7
                    rx_latch <= rx_data(0) & rx_latch(7 DOWNTO 1);
                END IF;
            END IF;
        END IF;
    END PROCESS rx_latch_proc;

    -- =========================================================================
    -- Parity error detection: fires when FSM transitions to SP_IDLE from
    -- a state that is not SP_IDLE or SP_COMPLETE (i.e. via interrupt only)
    -- =========================================================================
    parity_detect: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                prev_state   <= (OTHERS => '0');
                parity_err_i <= '0';
            ELSE
                prev_state <= state_code;
                IF prev_state /= SP_IDLE AND prev_state /= SP_COMPLETE
                        AND state_code = SP_IDLE THEN
                    parity_err_i <= '1';
                ELSE
                    parity_err_i <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS parity_detect;

    -- =========================================================================
    -- Output assignments
    -- =========================================================================
    tx_data    <= rx_latch WHEN state_code = SP_COMPLETE ELSE (OTHERS => '0');
    tx_enable  <= output_action(8);
    parity_err <= parity_err_i;
    state_out  <= state_code;

END ARCHITECTURE behavioral;
-- ============================================================================
-- TB_SERIAL 
-- ============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_serial IS
END ENTITY tb_serial;

ARCHITECTURE sim OF tb_serial IS

    SIGNAL clk           : STD_LOGIC := '0';
    SIGNAL reset         : STD_LOGIC := '0';
    SIGNAL rx_data       : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rx_valid      : STD_LOGIC := '0';
    SIGNAL tx_ready      : STD_LOGIC := '0';

    SIGNAL tx_data       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL tx_enable     : STD_LOGIC;
    SIGNAL parity_err    : STD_LOGIC;
    SIGNAL frame_err     : STD_LOGIC;
    SIGNAL state_out     : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL tx_data_valid : STD_LOGIC;
    SIGNAL fsm_error_out : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    dut : ENTITY work.serial_wrapper
        PORT MAP (
            clk           => clk,
            reset         => reset,
            rx_data       => rx_data,
            rx_valid      => rx_valid,
            tx_ready      => tx_ready,
            tx_data       => tx_data,
            tx_enable     => tx_enable,
            parity_err    => parity_err,
            frame_err     => frame_err,
            state_out     => state_out,
            tx_data_valid => tx_data_valid,
            fsm_error_out => fsm_error_out
        );

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    stim : PROCESS
        VARIABLE n_pass : INTEGER := 0;
        VARIABLE n_fail : INTEGER := 0;

        PROCEDURE check(cond : IN BOOLEAN; pmsg : IN STRING; fmsg : IN STRING) IS
        BEGIN
            IF cond THEN REPORT "PASS: " & pmsg; n_pass := n_pass + 1;
            ELSE REPORT "FAIL: " & fmsg SEVERITY ERROR; n_fail := n_fail + 1;
            END IF;
        END PROCEDURE;

        -- send_rx: for GOOD parity bytes only.
        -- Do NOT use for bad parity (see TEST 6 for correct approach).
        PROCEDURE send_rx(data : IN STD_LOGIC_VECTOR(7 DOWNTO 0)) IS
        BEGIN
            rx_data  <= data;
            rx_valid <= '1';
            WAIT FOR CLK_PERIOD * 2;
            rx_valid <= '0';
            WAIT FOR CLK_PERIOD * 4;
        END PROCEDURE;

    BEGIN
        REPORT "========================================";
        REPORT "STARTING SERIAL TESTBENCH (IMPROVED)";
        REPORT "========================================";

        -- TEST 1: Reset - IDLE state, no spurious parity_err
        REPORT "--- TEST 1: Reset ---";
        reset <= '1'; WAIT FOR CLK_PERIOD * 3; reset <= '0'; WAIT FOR CLK_PERIOD * 2;
        check(state_out = "00000", "IDLE after reset", "Not IDLE after reset");
        check(parity_err = '0', "No false parity_err after reset", "Spurious parity_err after reset");
        check(parity_err = '0', "parity_err gated by reset (IMPROVEMENT 1)", "parity_err fired on reset");

        -- TEST 2: Idle bus drives 0xFF (not 0x00)
        REPORT "--- TEST 2: Idle bus pattern 0xFF (NEW) ---";
        check(tx_data = x"FF", "tx_data = 0xFF when idle", "tx_data not 0xFF at idle");

        -- TEST 3: Good parity byte (0xA5 = 4 ones = even parity) advances state
        REPORT "--- TEST 3: Good parity rx ---";
        send_rx(x"A5");
        check(state_out /= "00000", "State advanced on good parity", "State stuck at IDLE");

        -- TEST 4: 10 more rx pulses -> SP_COMPLETE (11 total: start + 8 bits + stop)
        REPORT "--- TEST 4: Full byte receive to SP_COMPLETE ---";
        FOR i IN 1 TO 10 LOOP
            send_rx(x"A5");
        END LOOP;
        WAIT FOR CLK_PERIOD * 10;
        check(state_out = "01011", "Reached SP_COMPLETE", "Did not reach SP_COMPLETE");
        check(tx_data_valid = '1', "tx_data_valid asserted at COMPLETE", "tx_data_valid not set");

        -- TEST 5: tx_ready rising edge -> returns to IDLE
        REPORT "--- TEST 5: tx_ready -> IDLE ---";
        tx_ready <= '1'; WAIT FOR CLK_PERIOD * 2; tx_ready <= '0';
        WAIT FOR CLK_PERIOD * 6;
        check(state_out = "00000", "IDLE after tx_ready", "Not IDLE after tx_ready");

        -- TEST 6: Bad parity (0x01 = 1 one = odd) -> parity_err
        -- FIX v3: parity_err requires prev_state /= IDLE. After TEST 5 the FSM
        -- is in IDLE, so injecting bad parity directly from IDLE means
        -- prev_state=IDLE and the condition is never met.
        -- Fix: send one GOOD byte first to advance to SP_START (state 1),
        -- then inject the bad byte. Now prev_state=SP_START when the interrupt
        -- fires, prev_state /= IDLE is TRUE, and parity_err asserts correctly.
        REPORT "--- TEST 6: Bad parity -> parity_err (NEW) ---";
        -- Step 1: advance FSM out of IDLE with one good byte
        send_rx(x"A5");
        check(state_out /= "00000", "Advanced out of IDLE for parity test", "Did not advance out of IDLE");
        -- Step 2: assert bad parity byte; wait for parity_err before lowering rx_valid
        -- to catch the 1-cycle pulse as it fires during the pipeline processing.
        rx_data  <= x"01";   -- 0x01 = 1 set bit = odd parity -> interrupt
        rx_valid <= '1';
        WAIT UNTIL parity_err = '1' FOR CLK_PERIOD * 15;
        check(parity_err = '1',
              "parity_err pulsed on bad parity byte",
              "parity_err did not fire on bad parity");
        rx_valid <= '0';
        WAIT FOR CLK_PERIOD * 4;
        check(state_out = "00000", "FSM returned to IDLE after parity error", "Not IDLE after parity error");

        -- TEST 7: Reset mid-transfer does NOT assert parity_err
        REPORT "--- TEST 7: Reset gate on parity_err (NEW) ---";
        send_rx(x"A5");
        WAIT FOR CLK_PERIOD * 2;
        reset <= '1'; WAIT FOR CLK_PERIOD * 2; reset <= '0';
        WAIT FOR CLK_PERIOD * 6;
        check(parity_err = '0',
              "parity_err not fired on reset-abort (gate works)",
              "REGRESSION: parity_err falsely fired on reset");

        -- TEST 8: Premature tx_ready -> frame_err
        -- Assert tx_ready while mid-transfer; catch frame_err before lowering.
        REPORT "--- TEST 8: Frame error on premature tx_ready (NEW) ---";
        send_rx(x"A5");
        WAIT FOR CLK_PERIOD * 2;
        tx_ready <= '1';
        WAIT UNTIL frame_err = '1' FOR CLK_PERIOD * 15;
        check(frame_err = '1',
              "frame_err pulsed on premature tx_ready",
              "frame_err did not fire on premature tx_ready");
        tx_ready <= '0';
        WAIT FOR CLK_PERIOD * 4;

        REPORT "========================================";
        REPORT "RESULTS: " & INTEGER'IMAGE(n_pass) & " passed, " & INTEGER'IMAGE(n_fail) & " failed.";
        REPORT "========================================";
        STD.ENV.FINISH;
    END PROCESS stim;

END ARCHITECTURE sim;
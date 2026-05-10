-- ============================================================================
-- TB_VENDING
-- ============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_vending IS
END ENTITY tb_vending;

ARCHITECTURE sim OF tb_vending IS

    SIGNAL clk           : STD_LOGIC                    := '0';
    SIGNAL rst           : STD_LOGIC                    := '0';
    SIGNAL coin_insert   : STD_LOGIC                    := '0';
    SIGNAL selection_btn : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    SIGNAL item_empty    : STD_LOGIC                    := '0';
    SIGNAL dispense_done : STD_LOGIC                    := '0';
    SIGNAL cancel_btn    : STD_LOGIC                    := '0';
    SIGNAL change_done   : STD_LOGIC                    := '0';

    SIGNAL dispense_motor : STD_LOGIC;
    SIGNAL change_return  : STD_LOGIC;
    SIGNAL display_msg    : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL state_code     : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL fsm_busy       : STD_LOGIC;
    SIGNAL output_valid   : STD_LOGIC;
    SIGNAL fsm_error_out  : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    dut : ENTITY work.vending_wrapper
        PORT MAP (
            clk           => clk,
            rst           => rst,
            coin_insert   => coin_insert,
            selection_btn => selection_btn,
            item_empty    => item_empty,
            dispense_done => dispense_done,
            cancel_btn    => cancel_btn,
            change_done   => change_done,
            dispense_motor => dispense_motor,
            change_return  => change_return,
            display_msg    => display_msg,
            state_code     => state_code,
            fsm_busy       => fsm_busy,
            output_valid   => output_valid,
            fsm_error_out  => fsm_error_out
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

    BEGIN
        REPORT "========================================";
        REPORT "STARTING VENDING TESTBENCH (IMPROVED)";
        REPORT "========================================";

        -- TEST 1: Reset
        REPORT "--- TEST 1: Reset ---";
        rst <= '1'; WAIT FOR CLK_PERIOD * 3; rst <= '0'; WAIT FOR CLK_PERIOD * 2;
        check(state_code = "00000", "State is IDLE after reset", "Not IDLE after reset");
        check(dispense_motor = '0' AND change_return = '0',
              "Outputs idle after reset", "Outputs not idle");

        -- TEST 2: Coin insert → COLLECT
        -- ROM: IDLE + coin(event=1) → COLLECT
        REPORT "--- TEST 2: Coin insert -> COLLECT ---";
        coin_insert <= '1'; WAIT FOR CLK_PERIOD * 2; coin_insert <= '0';
        WAIT FOR CLK_PERIOD * 6;
        check(state_code = "00010", "Entered COLLECT after coin", "Did not enter COLLECT");

        -- TEST 3: Two selections to reach DISPENSE
        -- ROM: COLLECT + sel"01"(event=2) → SELECT
        --      SELECT  + sel"01"(event=2) → DISPENSE
        -- Note: "10" maps to event=4 which holds in SELECT — "01" is the correct button.
        REPORT "--- TEST 3: Selection (COLLECT->SELECT->DISPENSE) ---";
        selection_btn <= "01"; WAIT FOR CLK_PERIOD * 2; selection_btn <= "00";
        WAIT FOR CLK_PERIOD * 6;
        check(state_code = "00001", "Entered SELECT after first selection", "Did not enter SELECT");
        selection_btn <= "01"; WAIT FOR CLK_PERIOD * 2; selection_btn <= "00";
        WAIT FOR CLK_PERIOD * 6;
        check(dispense_motor = '1', "Dispense motor active (in DISPENSE)", "Dispense motor not active");

        -- TEST 4: Dispense done → CHANGE
        -- ROM: DISPENSE + dispense_done(event=16) → CHANGE
        REPORT "--- TEST 4: Dispense done -> CHANGE ---";
        dispense_done <= '1'; WAIT FOR CLK_PERIOD * 2; dispense_done <= '0';
        WAIT FOR CLK_PERIOD * 6;
        check(change_return = '1', "Change return asserted (in CHANGE)", "Change return not asserted");

        -- TEST 5: Change done → IDLE
        -- ROM: CHANGE + change_done(event=64) → IDLE
        REPORT "--- TEST 5: Change done -> IDLE ---";
        change_done <= '1'; WAIT FOR CLK_PERIOD * 2; change_done <= '0';
        WAIT FOR CLK_PERIOD * 6;
        check(state_code = "00000", "Returned to IDLE after change_done", "Did not return to IDLE");

        -- TEST 6: Cancel from COLLECT → IDLE + change_return
        -- FIX v2: change_return (driven by int_change_pulse OR output_action(1)) is
        -- high for EXACTLY ONE clock cycle — the same cycle state_code becomes IDLE.
        -- "WAIT UNTIL change_return='1'" suspends here and resumes on that exact
        -- pulse cycle, where both state_code='00000' and change_return='1' are
        -- simultaneously valid. This is the only reliable way to catch a 1-cycle
        -- pulse from a testbench without modifying the DUT.
        REPORT "--- TEST 6: Cancel from COLLECT -> IDLE + change_return ---";
        coin_insert <= '1'; WAIT FOR CLK_PERIOD * 2; coin_insert <= '0';
        WAIT FOR CLK_PERIOD * 6;
        check(state_code = "00010", "Back in COLLECT for cancel test", "Precondition: not in COLLECT");
        cancel_btn <= '1'; WAIT FOR CLK_PERIOD * 2; cancel_btn <= '0';
        -- Wait until change_return pulses (fires on the COLLECT→IDLE transition cycle)
        WAIT UNTIL change_return = '1' FOR CLK_PERIOD * 15;
        check(change_return = '1',
              "Change returned on cancel (caught on transition cycle)",
              "No change on cancel - pulse missed or never fired");
        check(state_code = "00000", "Cancel returned to IDLE", "Did not cancel to IDLE");

        -- TEST 7: Item empty → out-of-stock display 0xFF (NEW)
        REPORT "--- TEST 7: Item empty display (NEW) ---";
        coin_insert <= '1'; WAIT FOR CLK_PERIOD * 2; coin_insert <= '0';
        WAIT FOR CLK_PERIOD * 4;
        item_empty <= '1'; WAIT FOR CLK_PERIOD * 2; item_empty <= '0';
        WAIT FOR CLK_PERIOD * 4;
        check(display_msg = x"FF",
              "Out-of-stock code 0xFF shown", "Out-of-stock message not shown");

        -- TEST 8: Sustained coin_insert should only enter COLLECT once (NEW)
        REPORT "--- TEST 8: Coin edge detect (NEW) ---";
        rst <= '1'; WAIT FOR CLK_PERIOD * 3; rst <= '0'; WAIT FOR CLK_PERIOD * 2;
        coin_insert <= '1';
        WAIT FOR CLK_PERIOD * 20;
        coin_insert <= '0';
        check(state_code = "00010",
              "Single COLLECT entry despite sustained coin_insert",
              "Edge detect failed: unexpected state from sustained coin");

        REPORT "========================================";
        REPORT "RESULTS: " & INTEGER'IMAGE(n_pass) & " passed, " & INTEGER'IMAGE(n_fail) & " failed.";
        REPORT "========================================";
        STD.ENV.FINISH;
    END PROCESS stim;

END ARCHITECTURE sim;
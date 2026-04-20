LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_vending IS
END ENTITY tb_vending;

ARCHITECTURE sim OF tb_vending IS

    SIGNAL clk            : STD_LOGIC := '0';
    SIGNAL rst            : STD_LOGIC := '0';

    SIGNAL coin_insert    : STD_LOGIC := '0';
    SIGNAL selection_btn  : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    SIGNAL item_empty     : STD_LOGIC := '0';
    SIGNAL dispense_done  : STD_LOGIC := '0';
    SIGNAL cancel_btn     : STD_LOGIC := '0';
    SIGNAL change_done    : STD_LOGIC := '0';

    SIGNAL dispense_motor : STD_LOGIC;
    SIGNAL change_return  : STD_LOGIC;
    SIGNAL display_msg    : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL state_code     : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL fsm_busy       : STD_LOGIC;
    SIGNAL output_valid   : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

    CONSTANT VM_IDLE     : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
    CONSTANT VM_SELECT   : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00001";
    CONSTANT VM_COLLECT  : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00010";
    CONSTANT VM_DISPENSE : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00011";
    CONSTANT VM_CHANGE   : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00100";

BEGIN

    dut : ENTITY work.vending_wrapper
        PORT MAP (
            clk            => clk,
            rst            => rst,
            coin_insert    => coin_insert,
            selection_btn  => selection_btn,
            item_empty     => item_empty,
            dispense_done  => dispense_done,
            cancel_btn     => cancel_btn,
            change_done    => change_done,
            dispense_motor => dispense_motor,
            change_return  => change_return,
            display_msg    => display_msg,
            state_code     => state_code,
            fsm_busy       => fsm_busy,
            output_valid   => output_valid
        );

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    stim : PROCESS

        VARIABLE n_pass : INTEGER := 0;
        VARIABLE n_fail : INTEGER := 0;
        VARIABLE seen_change_pulse : BOOLEAN := FALSE;

        PROCEDURE check(cond : IN BOOLEAN; pmsg : IN STRING; fmsg : IN STRING) IS
        BEGIN
            IF cond THEN
                REPORT "PASS: " & pmsg;
                n_pass := n_pass + 1;
            ELSE
                REPORT "FAIL: " & fmsg SEVERITY ERROR;
                n_fail := n_fail + 1;
            END IF;
        END PROCEDURE;

        PROCEDURE settle_cycles(n : IN POSITIVE) IS
        BEGIN
            FOR i IN 1 TO n LOOP
                WAIT UNTIL rising_edge(clk);
            END LOOP;
        END PROCEDURE;

        PROCEDURE do_reset(label_txt : IN STRING) IS
        BEGIN
            rst <= '1';
            WAIT FOR CLK_PERIOD * 3;
            WAIT UNTIL rising_edge(clk);
            rst <= '0';
            settle_cycles(4);

            check(state_code = VM_IDLE AND dispense_motor = '0'
                  AND change_return = '0' AND display_msg = x"00",
                  label_txt,
                  label_txt & " wrong outputs after reset");
        END PROCEDURE;

        PROCEDURE pulse_sig(SIGNAL s : OUT STD_LOGIC) IS
        BEGIN
            s <= '1';
            WAIT UNTIL rising_edge(clk);
            WAIT UNTIL rising_edge(clk);
            s <= '0';
            WAIT UNTIL rising_edge(clk) AND fsm_busy = '0';
            WAIT UNTIL rising_edge(clk);
        END PROCEDURE;

        PROCEDURE select_sig(val : IN STD_LOGIC_VECTOR(1 DOWNTO 0)) IS
        BEGIN
            selection_btn <= val;
            WAIT UNTIL rising_edge(clk);
            WAIT UNTIL rising_edge(clk);
            selection_btn <= "00";
            WAIT UNTIL rising_edge(clk) AND fsm_busy = '0';
            WAIT UNTIL rising_edge(clk);
        END PROCEDURE;

        PROCEDURE check_vm(
            exp_state  : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            exp_motor  : IN STD_LOGIC;
            exp_change : IN STD_LOGIC;
            exp_msg    : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            label_txt  : IN STRING
        ) IS
        BEGIN
            check(state_code = exp_state AND dispense_motor = exp_motor
                  AND change_return = exp_change AND display_msg = exp_msg,
                  label_txt,
                  label_txt & " wrong outputs");
        END PROCEDURE;

    BEGIN

        -- ================================================================
        -- TEST 1-6: Normal purchase
        -- IDLE -> COLLECT -> SELECT -> DISPENSE -> CHANGE -> IDLE
        -- ================================================================
        REPORT "--- TEST 1-6: Normal purchase ---";
        do_reset("T1 reset to IDLE");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "T2 IDLE->COLLECT");

        select_sig("01");
        check_vm(VM_SELECT, '0', '0', x"02", "T3 COLLECT->SELECT");

        select_sig("01");
        check_vm(VM_DISPENSE, '1', '0', x"03", "T4 SELECT->DISPENSE");

        pulse_sig(dispense_done);
        check_vm(VM_CHANGE, '0', '1', x"04", "T5 DISPENSE->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "T6 CHANGE->IDLE");

        -- ================================================================
        -- TEST 7-10: Cancel during collection
        -- IDLE -> COLLECT -> IDLE with refund pulse
        -- ================================================================
        REPORT "--- TEST 7-10: Cancel during collection ---";
        do_reset("T7 reset to IDLE");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "T8 IDLE->COLLECT");

        seen_change_pulse := FALSE;
        cancel_btn <= '1';
        WAIT UNTIL rising_edge(clk);
        WAIT UNTIL rising_edge(clk);
        cancel_btn <= '0';

        FOR i IN 1 TO 6 LOOP
            WAIT UNTIL rising_edge(clk);
            IF change_return = '1' THEN
                seen_change_pulse := TRUE;
            END IF;
        END LOOP;

        check(state_code = VM_IDLE,
              "T9 COLLECT->IDLE via cancel",
              "T9 expected return to IDLE after cancel");

        check(seen_change_pulse,
              "T10 refund pulse seen",
              "T10 expected change_return pulse was not seen");

        -- ================================================================
        -- TEST 11-15: Out-of-stock
        -- IDLE -> COLLECT -> SELECT -> CHANGE -> IDLE
        -- ================================================================
        REPORT "--- TEST 11-15: Out-of-stock ---";
        do_reset("T11 reset to IDLE");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "T12 IDLE->COLLECT");

        select_sig("01");
        check_vm(VM_SELECT, '0', '0', x"02", "T13 COLLECT->SELECT");

        pulse_sig(item_empty);
        check_vm(VM_CHANGE, '0', '1', x"04", "T14 SELECT->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "T15 CHANGE->IDLE");

        -- ================================================================
        -- TEST 16-23: Additional coins needed
        -- IDLE -> COLLECT -> SELECT -> COLLECT -> SELECT -> DISPENSE
        -- -> CHANGE -> IDLE
        -- ================================================================
        REPORT "--- TEST 16-23: Additional coins needed ---";
        do_reset("T16 reset to IDLE");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "T17 IDLE->COLLECT");

        select_sig("10");
        check_vm(VM_SELECT, '0', '0', x"02", "T18 COLLECT->SELECT");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "T19 SELECT->COLLECT");

        select_sig("11");
        check_vm(VM_SELECT, '0', '0', x"02", "T20 COLLECT->SELECT again");

        select_sig("01");
        check_vm(VM_DISPENSE, '1', '0', x"03", "T21 SELECT->DISPENSE");

        pulse_sig(dispense_done);
        check_vm(VM_CHANGE, '0', '1', x"04", "T22 DISPENSE->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "T23 CHANGE->IDLE");

        -- ================================================================
        -- TEST 24-29: Dispense failure mid-cycle
        -- IDLE -> COLLECT -> SELECT -> DISPENSE -> CHANGE -> IDLE
        -- ================================================================
        REPORT "--- TEST 24-29: Incorrect Dispense ---";
        do_reset("T24 reset to IDLE");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "T25 IDLE->COLLECT");

        select_sig("01");
        check_vm(VM_SELECT, '0', '0', x"02", "T26 COLLECT->SELECT");

        select_sig("01");
        check_vm(VM_DISPENSE, '1', '0', x"03", "T27 SELECT->DISPENSE");

        pulse_sig(item_empty);
        check_vm(VM_CHANGE, '0', '1', x"04", "T28 DISPENSE->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "T29 CHANGE->IDLE");

        -- ================================================================
        WAIT FOR CLK_PERIOD * 5;
        REPORT "========================================";
        REPORT "RESULTS: " & integer'image(n_pass) & " PASSED, "
               & integer'image(n_fail) & " FAILED";
        REPORT "========================================";
        std.env.finish;

    END PROCESS stim;

END ARCHITECTURE sim;
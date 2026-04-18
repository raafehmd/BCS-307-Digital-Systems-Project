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

        PROCEDURE do_reset IS
        BEGIN
            rst <= '1';
            WAIT FOR CLK_PERIOD * 3;
            WAIT UNTIL rising_edge(clk);
            rst <= '0';
            settle_cycles(4);

            check(state_code = VM_IDLE,
                  "VM_IDLE after reset",
                  "Expected VM_IDLE after reset");
            check(dispense_motor = '0',
                  "dispense_motor=0 after reset",
                  "dispense_motor should be 0 after reset");
            check(change_return = '0',
                  "change_return=0 after reset",
                  "change_return should be 0 after reset");
            check(display_msg = x"00",
                  "display_msg=00 after reset",
                  "display_msg should be 00 after reset");
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
            check(state_code = exp_state,
                  label_txt & " state",
                  label_txt & " wrong state");

            check(dispense_motor = exp_motor,
                  label_txt & " dispense_motor",
                  label_txt & " wrong dispense_motor");

            check(change_return = exp_change,
                  label_txt & " change_return",
                  label_txt & " wrong change_return");

            check(display_msg = exp_msg,
                  label_txt & " display_msg",
                  label_txt & " wrong display_msg");
        END PROCEDURE;

    BEGIN

        -- ============================================================
        -- Scenario 1: Normal purchase
        -- IDLE -> COLLECT -> SELECT -> DISPENSE -> CHANGE -> IDLE
        -- ============================================================
        REPORT "--- SCENARIO 1: Normal purchase ---";
        do_reset;

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "S1 IDLE->COLLECT");

        select_sig("01");
        check_vm(VM_SELECT, '0', '0', x"02", "S1 COLLECT->SELECT");

        select_sig("01");
        check_vm(VM_DISPENSE, '1', '0', x"03", "S1 SELECT->DISPENSE");

        pulse_sig(dispense_done);
        check_vm(VM_CHANGE, '0', '1', x"04", "S1 DISPENSE->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "S1 CHANGE->IDLE");

        -- ============================================================
        -- Scenario 2: Cancel during collection
        -- IDLE -> COLLECT -> IDLE with refund pulse
        -- ============================================================
        REPORT "--- SCENARIO 2: Cancel during collection ---";
        do_reset;

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "S2 IDLE->COLLECT");

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
              "S2 COLLECT->IDLE via cancel",
              "S2 expected return to IDLE after cancel");

        check(seen_change_pulse,
              "S2 refund pulse seen",
              "S2 expected change_return pulse was not seen");

        -- ============================================================
        -- Scenario 3: Out-of-stock
        -- IDLE -> COLLECT -> SELECT -> CHANGE -> IDLE
        -- ============================================================
        REPORT "--- SCENARIO 3: Out-of-stock ---";
        do_reset;

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "S3 IDLE->COLLECT");

        select_sig("01");
        check_vm(VM_SELECT, '0', '0', x"02", "S3 COLLECT->SELECT");

        pulse_sig(item_empty);
        check_vm(VM_CHANGE, '0', '1', x"04", "S3 SELECT->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "S3 CHANGE->IDLE");

        -- ============================================================
        -- Scenario 4: Additional coins needed
        -- IDLE -> COLLECT -> SELECT -> COLLECT -> SELECT -> DISPENSE
        -- -> CHANGE -> IDLE
        -- ============================================================
        REPORT "--- SCENARIO 4: Additional coins needed ---";
        do_reset;

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "S4 IDLE->COLLECT");

        select_sig("10");
        check_vm(VM_SELECT, '0', '0', x"02", "S4 COLLECT->SELECT");

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "S4 SELECT->COLLECT");

        select_sig("11");
        check_vm(VM_SELECT, '0', '0', x"02", "S4 COLLECT->SELECT again");

        select_sig("01");
        check_vm(VM_DISPENSE, '1', '0', x"03", "S4 SELECT->DISPENSE");

        pulse_sig(dispense_done);
        check_vm(VM_CHANGE, '0', '1', x"04", "S4 DISPENSE->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "S4 CHANGE->IDLE");

        -- ============================================================
        -- Scenario 5: Dispense failure mid-cycle
        -- IDLE -> COLLECT -> SELECT -> DISPENSE -> CHANGE -> IDLE
        -- ============================================================
        REPORT "--- SCENARIO 5: Dispense failure ---";
        do_reset;

        pulse_sig(coin_insert);
        check_vm(VM_COLLECT, '0', '0', x"01", "S5 IDLE->COLLECT");

        select_sig("01");
        check_vm(VM_SELECT, '0', '0', x"02", "S5 COLLECT->SELECT");

        select_sig("01");
        check_vm(VM_DISPENSE, '1', '0', x"03", "S5 SELECT->DISPENSE");

        pulse_sig(item_empty);
        check_vm(VM_CHANGE, '0', '1', x"04", "S5 DISPENSE->CHANGE");

        pulse_sig(change_done);
        check_vm(VM_IDLE, '0', '0', x"00", "S5 CHANGE->IDLE");

        WAIT FOR CLK_PERIOD * 5;
        REPORT "========================================";
        REPORT "RESULTS: " & integer'image(n_pass) & " PASSED, "
               & integer'image(n_fail) & " FAILED";
        REPORT "========================================";
        std.env.finish;

    END PROCESS stim;

END ARCHITECTURE sim;

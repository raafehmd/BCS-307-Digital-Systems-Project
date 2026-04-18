LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_traffic_light IS
END ENTITY tb_traffic_light;

ARCHITECTURE sim OF tb_traffic_light IS

    SIGNAL clk            : STD_LOGIC := '0';
    SIGNAL reset          : STD_LOGIC := '0';
    SIGNAL pedestrian_btn : STD_LOGIC := '0';
    SIGNAL car_sensor     : STD_LOGIC := '0';
    SIGNAL timer_done     : STD_LOGIC := '0';

    SIGNAL red_led        : STD_LOGIC;
    SIGNAL yellow_led     : STD_LOGIC;
    SIGNAL green_led      : STD_LOGIC;
    SIGNAL ped_signal     : STD_LOGIC;
    SIGNAL timer_start    : STD_LOGIC;
    SIGNAL timer_reset    : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    dut : ENTITY work.traffic_light_wrapper
        PORT MAP (
            clk            => clk,
            reset          => reset,
            pedestrian_btn => pedestrian_btn,
            car_sensor     => car_sensor,
            timer_done     => timer_done,
            red_led        => red_led,
            yellow_led     => yellow_led,
            green_led      => green_led,
            ped_signal     => ped_signal,
            timer_start    => timer_start,
            timer_reset    => timer_reset
        );

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    stim : PROCESS

        VARIABLE n_pass : INTEGER := 0;
        VARIABLE n_fail : INTEGER := 0;

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

        PROCEDURE pulse_sig(SIGNAL s : OUT STD_LOGIC) IS
        BEGIN
            s <= '1';
            WAIT UNTIL rising_edge(clk);
            WAIT UNTIL rising_edge(clk);
            s <= '0';
            WAIT UNTIL rising_edge(clk);
        END PROCEDURE;

        PROCEDURE do_reset IS
        BEGIN
            reset <= '1';
            WAIT FOR CLK_PERIOD * 3;
            WAIT UNTIL rising_edge(clk);
            reset <= '0';
            settle_cycles(4);
        END PROCEDURE;

        PROCEDURE check_lights(
            exp_red  : IN STD_LOGIC;
            exp_yel  : IN STD_LOGIC;
            exp_grn  : IN STD_LOGIC;
            exp_ped  : IN STD_LOGIC;
            label_txt : IN STRING
        ) IS
        BEGIN
            check(red_led = exp_red,
                  label_txt & " red_led",
                  label_txt & " wrong red_led");

            check(yellow_led = exp_yel,
                  label_txt & " yellow_led",
                  label_txt & " wrong yellow_led");

            check(green_led = exp_grn,
                  label_txt & " green_led",
                  label_txt & " wrong green_led");

            check(ped_signal = exp_ped,
                  label_txt & " ped_signal",
                  label_txt & " wrong ped_signal");
        END PROCEDURE;

    BEGIN

        -- ============================================================
        -- TEST 1: Reset / IDLE
        -- ============================================================
        REPORT "--- TEST 1: Reset -> IDLE ---";
        do_reset;
        check_lights('0', '0', '0', '0', "T1 reset to IDLE");

        -- ============================================================
        -- TEST 2: Normal car cycle
        -- IDLE -> RED -> GREEN -> YELLOW -> RED
        -- ============================================================
        REPORT "--- TEST 2: Normal car cycle ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T2 IDLE->RED");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '0', '1', '0', "T2 RED->GREEN");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '1', '0', '0', "T2 GREEN->YELLOW");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T2 YELLOW->RED");

        -- ============================================================
        -- TEST 3: Ignore car while already RED
        -- ============================================================
        REPORT "--- TEST 3: Ignore car while RED ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T3 enter RED");

        pulse_sig(car_sensor);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T3 RED holds on car");

        -- ============================================================
        -- TEST 4: Ignore car while GREEN
        -- ============================================================
        REPORT "--- TEST 4: Ignore car while GREEN ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '0', '1', '0', "T4 enter GREEN");

        pulse_sig(car_sensor);
        settle_cycles(3);
        check_lights('0', '0', '1', '0', "T4 GREEN holds on car");

        -- ============================================================
        -- TEST 5: Ignore pedestrian while YELLOW
        -- ============================================================
        REPORT "--- TEST 5: Ignore pedestrian while YELLOW ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        pulse_sig(timer_done);
        settle_cycles(3);
        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '1', '0', '0', "T5 enter YELLOW");

        pulse_sig(pedestrian_btn);
        settle_cycles(3);
        check_lights('0', '1', '0', '0', "T5 YELLOW holds on ped");

        -- ============================================================
        -- TEST 6: Pedestrian request from GREEN
        -- IDLE -> RED -> GREEN -> PED_WAIT -> PED_CROSS -> RED
        -- ============================================================
        REPORT "--- TEST 6: Pedestrian from GREEN ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '0', '1', '0', "T6 enter GREEN");

        pulse_sig(pedestrian_btn);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T6 GREEN->PED_WAIT");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('1', '0', '0', '1', "T6 PED_WAIT->PED_CROSS");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T6 PED_CROSS->RED");

        -- ============================================================
        -- TEST 7: Pedestrian request from RED
        -- IDLE -> RED -> PED_WAIT -> PED_CROSS -> RED
        -- ============================================================
        REPORT "--- TEST 7: Pedestrian from RED ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T7 enter RED");

        pulse_sig(pedestrian_btn);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T7 RED->PED_WAIT");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('1', '0', '0', '1', "T7 PED_WAIT->PED_CROSS");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T7 PED_CROSS->RED");

        -- ============================================================
        -- TEST 8: Pedestrian request from IDLE
        -- Current ROM/test intent: IDLE -> RED -> GREEN -> YELLOW -> RED
        -- ============================================================
        REPORT "--- TEST 8: Pedestrian from IDLE ---";
        do_reset;

        pulse_sig(pedestrian_btn);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T8 IDLE->RED by ped");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '0', '1', '0', "T8 RED->GREEN");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '1', '0', '0', "T8 GREEN->YELLOW");

        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('1', '0', '0', '0', "T8 YELLOW->RED");

        -- ============================================================
        -- TEST 9: Reset during active state
        -- ============================================================
        REPORT "--- TEST 9: Reset during active state ---";
        do_reset;

        pulse_sig(car_sensor);
        settle_cycles(3);
        pulse_sig(timer_done);
        settle_cycles(3);
        check_lights('0', '0', '1', '0', "T9 active GREEN before reset");

        reset <= '1';
        WAIT FOR CLK_PERIOD * 2;
        WAIT UNTIL rising_edge(clk);
        reset <= '0';
        settle_cycles(4);
        check_lights('0', '0', '0', '0', "T9 reset back to IDLE");

        -- ============================================================
        WAIT FOR CLK_PERIOD * 5;
        REPORT "========================================";
        REPORT "RESULTS: " & integer'image(n_pass) & " PASSED, "
               & integer'image(n_fail) & " FAILED";
        REPORT "========================================";
        std.env.finish;

    END PROCESS stim;

END ARCHITECTURE sim;

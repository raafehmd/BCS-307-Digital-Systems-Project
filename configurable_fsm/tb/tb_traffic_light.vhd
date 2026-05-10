-- ============================================================================
-- TB_TRAFFIC_LIGHT
-- ============================================================================
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
    SIGNAL input_conflict : STD_LOGIC;
    SIGNAL fault_err      : STD_LOGIC;
    SIGNAL fsm_error_out  : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    dut : ENTITY work.traffic_light_wrapper
        PORT MAP (
            clk             => clk,
            reset           => reset,
            pedestrian_btn  => pedestrian_btn,
            car_sensor      => car_sensor,
            timer_done      => timer_done,
            red_led         => red_led,
            yellow_led      => yellow_led,
            green_led       => green_led,
            ped_signal      => ped_signal,
            timer_start     => timer_start,
            timer_reset     => timer_reset,
            input_conflict  => input_conflict,
            fault_err       => fault_err,
            fsm_error_out   => fsm_error_out
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
        REPORT "STARTING TRAFFIC LIGHT TESTBENCH (IMPROVED)";
        REPORT "========================================";

        -- TEST 1: Reset — all LEDs off, timer reset held then cleared
        REPORT "--- TEST 1: Reset ---";
        reset <= '1'; WAIT FOR CLK_PERIOD * 3; reset <= '0'; WAIT FOR CLK_PERIOD * 2;
        check(red_led = '0' AND green_led = '0' AND yellow_led = '0',
              "All LEDs off after reset", "LEDs not off after reset");
        check(timer_reset = '1', "Timer reset held after reset", "Timer reset not held");
        WAIT FOR CLK_PERIOD * 5;
        check(timer_reset = '0', "Timer reset cleared after hold", "Timer reset not cleared");

        -- TEST 2: Car arrival → RED (IDLE + car_sensor → RED per ROM addr 2)
        -- FIX: ROM maps IDLE+car → RED, not GREEN. GREEN requires a timer tick from RED.
        REPORT "--- TEST 2: Car arrival -> RED ---";
        car_sensor <= '1'; WAIT FOR CLK_PERIOD * 2; car_sensor <= '0';
        WAIT FOR CLK_PERIOD * 8;
        check(red_led = '1' AND green_led = '0',
              "RED active after car arrival (IDLE->RED)", "RED not active after car arrival");

        -- TEST 3: Timer expire RED → GREEN (ROM addr 1028: RED+timer_done→GREEN)
        REPORT "--- TEST 3: Timer expire (RED -> GREEN) ---";
        timer_done <= '1'; WAIT FOR CLK_PERIOD * 2; timer_done <= '0';
        WAIT FOR CLK_PERIOD * 8;
        check(green_led = '1' AND red_led = '0',
              "GREEN active after RED timer", "GREEN not active after RED timer");

        -- TEST 4: Timer expire GREEN → YELLOW (ROM addr 2052: GREEN+timer_done→YELLOW)
        REPORT "--- TEST 4: Timer expire (GREEN -> YELLOW) ---";
        timer_done <= '1'; WAIT FOR CLK_PERIOD * 2; timer_done <= '0';
        WAIT FOR CLK_PERIOD * 8;
        check(yellow_led = '1' AND green_led = '0',
              "YELLOW active after GREEN timer", "YELLOW not active after GREEN timer");

        -- TEST 5: Timer expire YELLOW → RED (ROM addr 3076: YELLOW+timer_done→RED)
        REPORT "--- TEST 5: Timer expire (YELLOW -> RED) ---";
        timer_done <= '1'; WAIT FOR CLK_PERIOD * 2; timer_done <= '0';
        WAIT FOR CLK_PERIOD * 8;
        check(red_led = '1' AND yellow_led = '0',
              "RED active after YELLOW timer", "RED not active after YELLOW timer");

        -- TEST 6: Pedestrian request from RED → PED_WAIT
        -- (ROM addr 1025: RED+pedestrian→PED_WAIT, red held, ped_signal off)
        REPORT "--- TEST 6: Pedestrian request (RED -> PED_WAIT) ---";
        pedestrian_btn <= '1'; WAIT FOR CLK_PERIOD * 2; pedestrian_btn <= '0';
        WAIT FOR CLK_PERIOD * 8;
        check(ped_signal = '0' AND red_led = '1',
              "PED_WAIT: red held, ped_signal off", "PED_WAIT state wrong");

        -- TEST 7: Timer expire PED_WAIT → PED_CROSS
        -- (ROM addr 4100: PED_WAIT+timer_done→PED_CROSS, ped_signal on)
        REPORT "--- TEST 7: Timer expire (PED_WAIT -> PED_CROSS) ---";
        timer_done <= '1'; WAIT FOR CLK_PERIOD * 2; timer_done <= '0';
        WAIT FOR CLK_PERIOD * 8;
        check(ped_signal = '1' AND red_led = '1',
              "PED_CROSS: ped_signal on, red held", "PED_CROSS state wrong");

        -- TEST 8: Simultaneous input conflict detection (NEW)
        REPORT "--- TEST 8: Simultaneous inputs conflict (NEW) ---";
        pedestrian_btn <= '1'; car_sensor <= '1';
        WAIT FOR CLK_PERIOD * 2;
        check(input_conflict = '1', "Conflict detected on simultaneous inputs", "Conflict not detected");
        pedestrian_btn <= '0'; car_sensor <= '0';
        WAIT FOR CLK_PERIOD * 2;
        check(input_conflict = '0', "Conflict cleared", "Conflict not cleared");

        -- TEST 9: Fault on timer_done arriving in IDLE (NEW)
        REPORT "--- TEST 9: Fault on unexpected timer_done (NEW) ---";
        reset <= '1'; WAIT FOR CLK_PERIOD * 3; reset <= '0'; WAIT FOR CLK_PERIOD * 3;
        timer_done <= '1'; WAIT FOR CLK_PERIOD * 2; timer_done <= '0';
        WAIT FOR CLK_PERIOD * 4;
        check(fault_err = '1', "Fault flagged on timer_done in IDLE", "Fault not detected");

        REPORT "========================================";
        REPORT "RESULTS: " & INTEGER'IMAGE(n_pass) & " passed, " & INTEGER'IMAGE(n_fail) & " failed.";
        REPORT "========================================";
        STD.ENV.FINISH;
    END PROCESS stim;

END ARCHITECTURE sim;
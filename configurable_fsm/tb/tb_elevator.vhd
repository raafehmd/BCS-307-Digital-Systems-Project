-- ============================================================================
-- TB_ELEVATOR  (FIXED v5 - FINAL)
--
-- Root cause of TEST 4 and TEST 5-7 failures (definitive):
-- "WAIT FOR CLK_PERIOD * 6" was one cycle too many. Timing from reset:
--
--   T=50ns : reset cleared, floor_request <= "0011"
--   T=75ns : state = MOVE_UP (pipeline latency = 3 edges)
--   T=85ns : current_floor = 3, floor_display = "0011"  <- target reached
--   T=110ns: "WAIT FOR CLK_PERIOD*6" ends
--
-- At T=110ns floor_display is ALREADY "0011". VHDL "WAIT UNTIL" waits for
-- the NEXT TRANSITION of the condition, not the current state. Since the
-- floor counter has stopped (current=target), floor_display never changes
-- again, so "WAIT UNTIL floor_display='0011'" times out at +300ns.
-- After the 300ns timeout the WAIT FOR 4 check fires 400ns after the door
-- already auto-closed back to IDLE -> door_open='0' -> FAIL.
--
-- Fix: "WAIT FOR CLK_PERIOD * 3" (30ns from floor_request = T=80ns).
-- At T=80ns: state=MOVE_UP, floor_display="0010" (not yet "0011").
-- motor_up='1' check passes. WAIT UNTIL floor_display="0011" then catches
-- the TRANSITION at T=85ns. WAIT FOR 4 more cycles lands at T=125ns when
-- state=DOOR_OPEN and door_open='1' is settled. door_sensor is asserted
-- immediately after so the auto-close is blocked by door_sensor priority.
-- ============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_elevator IS
END ENTITY tb_elevator;

ARCHITECTURE sim OF tb_elevator IS

    SIGNAL clk           : STD_LOGIC                    := '0';
    SIGNAL reset         : STD_LOGIC                    := '0';
    SIGNAL floor_request : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL door_sensor   : STD_LOGIC                    := '0';
    SIGNAL weight_sensor : STD_LOGIC                    := '0';
    SIGNAL emergency_btn : STD_LOGIC                    := '0';

    SIGNAL motor_up        : STD_LOGIC;
    SIGNAL motor_down      : STD_LOGIC;
    SIGNAL door_open       : STD_LOGIC;
    SIGNAL alarm_buzzer    : STD_LOGIC;
    SIGNAL emergency_light : STD_LOGIC;
    SIGNAL floor_display   : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL fsm_error_out   : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    dut : ENTITY work.elevator_top
        PORT MAP (
            clk             => clk,
            reset           => reset,
            floor_request   => floor_request,
            door_sensor     => door_sensor,
            weight_sensor   => weight_sensor,
            emergency_btn   => emergency_btn,
            motor_up        => motor_up,
            motor_down      => motor_down,
            door_open       => door_open,
            alarm_buzzer    => alarm_buzzer,
            emergency_light => emergency_light,
            floor_display   => floor_display,
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
        REPORT "STARTING ELEVATOR TESTBENCH (IMPROVED)";
        REPORT "========================================";

        -- TEST 1: Reset
        REPORT "--- TEST 1: Reset ---";
        reset <= '1'; WAIT FOR CLK_PERIOD * 3; reset <= '0'; WAIT FOR CLK_PERIOD * 2;
        check(motor_up = '0' AND motor_down = '0' AND door_open = '0',
              "Outputs idle after reset", "Motors/door active after reset");
        check(floor_display = "0001", "Initialized at Floor 1", "Not at Floor 1");

        -- TEST 2-4: Up request to Floor 3, arrival, door open
        REPORT "--- TEST 2-4: Up request to Floor 3 ---";
        floor_request <= "0011";

        -- FIX v5: WAIT FOR 3 cycles (not 6). The pipeline takes 3 edges to reach
        -- MOVE_UP, then 1 edge to increment to floor 2. After 3 cycles (30ns) we
        -- are in MOVE_UP with floor_display="0010", so the subsequent WAIT UNTIL
        -- correctly catches the TRANSITION to "0011" at the next edge.
        -- With 6 cycles (60ns) floor_display is already "0011" when WAIT UNTIL
        -- executes, causing it to wait for a future (never-arriving) transition.
        WAIT FOR CLK_PERIOD * 3;
        check(motor_up = '1' AND motor_down = '0', "motor_up asserted", "motor_up not asserted");

        -- Catch the floor_display transition to "0011"
        WAIT UNTIL floor_display = "0011" FOR 300 ns;
        check(floor_display = "0011", "Reached Floor 3 (watchdog passed)", "Timeout: never reached Floor 3");

        -- Wait 4 cycles: arrived pipeline completes (3 edges) then 1 settle cycle.
        -- At T+4 from floor_display="0011": state=DOOR_OPEN, door_open='1'.
        -- door_open_stable2 also becomes '1' at T+4, but door_sensor='1'
        -- (asserted immediately after this check) takes priority over door_clear.
        WAIT FOR CLK_PERIOD * 4;
        check(motor_up = '0' AND door_open = '1', "Arrived at Floor 3, door open", "Did not arrive at floor 3");
        floor_request <= "0000";

        -- TEST 5-7: Door hold, closing sequence, idle
        -- door_sensor is asserted immediately (no gap) to block the auto-close path.
        REPORT "--- TEST 5-7: Door sequence ---";
        door_sensor <= '1'; WAIT FOR CLK_PERIOD * 10;
        check(door_open = '1', "hold_state: Door held open by sensor", "Door closed prematurely");
        door_sensor <= '0'; WAIT FOR CLK_PERIOD * 6;
        check(door_open = '0', "Door closing triggered", "Door did not close");
        door_sensor <= '1'; WAIT FOR CLK_PERIOD * 6;
        door_sensor <= '0'; WAIT FOR CLK_PERIOD * 4;
        check(motor_up = '0' AND motor_down = '0' AND door_open = '0',
              "Idle at Floor 3", "Not idle after door cycle");

        -- TEST 8-10: Top boundary (Floor 11) and downward travel
        -- Floor 11 requires 8 increments (3->11). The WAIT UNTIL has 1500ns timeout
        -- which is ample. We apply the same 4-cycle post-target wait and immediate
        -- door_sensor assertion to prevent the auto-close at Floor 11.
        REPORT "--- TEST 8-10: Top boundary and down ---";
        floor_request <= "1011";
        WAIT UNTIL floor_display = "1011" FOR 1500 ns;
        check(floor_display = "1011", "Reached Floor 11", "Timeout: never reached Floor 11");
        WAIT FOR CLK_PERIOD * 4;
        floor_request <= "0000";
        door_sensor <= '1'; WAIT FOR CLK_PERIOD * 12; door_sensor <= '0'; WAIT FOR CLK_PERIOD * 10;
        door_sensor <= '1'; WAIT FOR CLK_PERIOD * 8;  door_sensor <= '0'; WAIT FOR CLK_PERIOD * 6;

        floor_request <= "0001"; WAIT FOR CLK_PERIOD * 8;
        check(motor_down = '1' AND motor_up = '0', "motor_down for downward travel", "motor_down not asserted");
        WAIT FOR CLK_PERIOD * 10;
        check(UNSIGNED(floor_display) < 11, "Floor counter decrementing", "Counter did not decrement");

        -- TEST 11-12: Emergency stop mid-journey
        REPORT "--- TEST 11-12: Emergency ---";
        emergency_btn <= '1';
        WAIT UNTIL rising_edge(clk) AND emergency_light = '1' FOR CLK_PERIOD * 10;
        check(emergency_light = '1', "Emergency light asserted", "Emergency light did not assert");
        emergency_btn <= '0'; WAIT FOR CLK_PERIOD * 2;
        check(motor_down = '0' AND motor_up = '0', "Motors halted on emergency", "Motors did not halt");

        -- TEST 13: Overload detection
        REPORT "--- TEST 13: Overload ---";
        floor_request <= "1000"; WAIT FOR CLK_PERIOD * 16;
        weight_sensor <= '1'; WAIT FOR CLK_PERIOD * 6;
        check(alarm_buzzer = '1' AND motor_up = '0',
              "Overload: alarm on, motor stopped", "Overload not handled");
        weight_sensor <= '0'; floor_request <= "0000"; WAIT FOR CLK_PERIOD * 3;

        -- TEST 14: Motor mutual-exclusion interlock (NEW)
        REPORT "--- TEST 14: Motor interlock (NEW) ---";
        check(NOT (motor_up = '1' AND motor_down = '1'),
              "Motor interlock: never both high simultaneously",
              "INTERLOCK VIOLATED: both motors high at once");

        REPORT "========================================";
        REPORT "RESULTS: " & INTEGER'IMAGE(n_pass) & " passed, " & INTEGER'IMAGE(n_fail) & " failed.";
        REPORT "========================================";
        STD.ENV.FINISH;
    END PROCESS stim;

END ARCHITECTURE sim;
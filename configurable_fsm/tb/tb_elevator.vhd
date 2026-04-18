library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_elevator is
end entity tb_elevator;

architecture sim of tb_elevator is

  -- Wrapper input signals
  signal clk           : std_logic                    := '0';
  signal reset         : std_logic                    := '0';
  signal floor_request : std_logic_vector(3 downto 0) := (others => '0');
  signal door_sensor   : std_logic                    := '0';
  signal weight_sensor : std_logic                    := '0';
  signal emergency_btn : std_logic                    := '0';

  -- Wrapper output signals
  signal motor_up        : std_logic;
  signal motor_down      : std_logic;
  signal door_open       : std_logic;
  signal alarm_buzzer    : std_logic;
  signal emergency_light : std_logic;
  signal floor_display   : std_logic_vector(3 downto 0);

  constant CLK_PERIOD : time := 10 ns;

begin

  -- Instantiate the Unit Under Test (UUT)
  dut : entity work.elevator_top
    port map
    (
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
      floor_display   => floor_display
    );

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  -- Stimulus and verification process
  stim : process
    variable n_pass : integer := 0;
    variable n_fail : integer := 0;

    -- Helper procedure to tally passes/fails cleanly
    procedure check(cond : in boolean; pmsg : in string; fmsg : in string) is
    begin
      if cond then
        report "PASS: " & pmsg;
        n_pass := n_pass + 1;
      else
        report "FAIL: " & fmsg severity ERROR;
        n_fail := n_fail + 1;
      end if;
    end procedure;

  begin
    report "========================================";
    report "STARTING ELEVATOR WRAPPER TESTBENCH";
    report "========================================";

    -- ====================================================================
    -- TEST 1: Reset Initialization
    -- ====================================================================
    report "--- TEST 1: Reset Initialization ---";
      reset <= '1';
    wait for CLK_PERIOD * 3;
    reset <= '0';
    wait for CLK_PERIOD * 2;

    check(motor_up = '0' and motor_down = '0' and door_open = '0',
    "Outputs idle after reset", "Motors/door active after reset");
    check(floor_display = "0001",
    "Initialized at Floor 1", "Did not initialize to Floor 1");

    -- ====================================================================
    -- TEST 2, 4, 10: Up request & Floor tracking & Arrival
    -- ====================================================================
    report "--- TEST 2, 4, 10: Up request to Floor 3 ---";
      floor_request <= "0011"; -- Request Floor 3
    wait for CLK_PERIOD * 6; -- FSM pipeline needs ~5-6 cycles to settle

    check(motor_up = '1' and motor_down = '0',
    "motor_up asserted for upward travel", "motor_up not asserted");

    -- Wait for the internal counter to increment to Floor 3
    wait until floor_display = "0011" for 200 ns;
    wait for CLK_PERIOD * 6; -- Allow pipeline to process arrival event

    check(motor_up = '0' and door_open = '1',
    "Arrived at floor 3, door opened", "Failed to arrive and open door");

    floor_request <= "0000"; -- Clear request

    -- ====================================================================
    -- TEST 5, 6, 7: Door Hold, Closing Sequence, Idle Confirmation
    -- ====================================================================
    report "--- TEST 5, 6, 7: Door sequence ---";
      door_sensor <= '1'; -- Simulate door being blocked/held open
    wait for CLK_PERIOD * 10; -- Hold_state needs extra cycles to lock in

    check(door_open = '1',
    "hold_state active: Door held open by sensor", "Door closed prematurely");

    door_sensor <= '0'; -- Clear sensor -> wrapper generates door_clear event
    wait for CLK_PERIOD * 6; -- Pipeline processes DOOR_OPEN -> DOOR_CLOSE

    check(door_open = '0',
    "Door closing sequence triggered", "Door did not close");

    -- door_sensor=1 in DOOR_CLOSE state triggers safety trip -> IDLE
    door_sensor <= '1';
    wait for CLK_PERIOD * 6;
    door_sensor <= '0';
    wait for CLK_PERIOD * 4;

    check(motor_up = '0' and motor_down = '0' and door_open = '0',
    "Elevator confirmed idle at Floor 3", "Elevator did not return to idle");

    -- ====================================================================
    -- TEST 3, 11, 12, 13: Journey to boundary (Top), Down Request
    -- ====================================================================
    report "--- TEST 3, 11, 12: Journey to top boundary (Floor 11) ---";
      floor_request <= "1011"; -- Request Floor 11
    wait until floor_display = "1011" for 1000 ns;
    wait for CLK_PERIOD * 6;
    floor_request <= "0000";

    -- Cycle door to get back to idle
    door_sensor <= '1';
    wait for CLK_PERIOD * 12;
    door_sensor <= '0';
    wait for CLK_PERIOD * 10;
    door_sensor <= '1';
    wait for CLK_PERIOD * 8;
    door_sensor <= '0';
    wait for CLK_PERIOD * 6;

    report "--- TEST 3: Down request from Floor 11 ---";
      floor_request <= "0001"; -- Request Floor 1
    wait for CLK_PERIOD * 8;

    check(motor_down = '1' and motor_up = '0',
    "motor_down asserted for downward travel", "motor_down not asserted");

    -- Wait enough cycles to observe floor decrement
    wait for CLK_PERIOD * 10;
    check(unsigned(floor_display) < 11,
    "Floor counter decrementing properly", "Floor counter did not decrement");

    -- ====================================================================
    -- TEST 9, 15: Emergency Stop & Light Abort
    -- ====================================================================
    report "--- TEST 9, 15: Emergency interrupt mid-journey ---";
      -- We are currently moving down. Trigger emergency.
      -- emergency_light is a 1-cycle pulse from abort_detect.
      -- It fires on the cycle prev_state /= IDLE AND state = IDLE.
      -- Keep emergency_btn high and sample in a window of cycles.
      emergency_btn <= '1';
    -- Synchronise directly on the rising edge where emergency_light pulses.
    -- This is robust regardless of exact pipeline depth.
    wait until rising_edge(clk) and emergency_light = '1' for CLK_PERIOD * 10;

    check(emergency_light = '1',
    "Emergency light pulsed on abort", "Emergency light did not pulse");

    emergency_btn <= '0';
    wait for CLK_PERIOD * 2;

    check(motor_down = '0' and motor_up = '0',
    "Motors halted due to emergency return to idle", "Motors did not halt");

    -- ====================================================================
    -- TEST 8: Overload Detection
    -- ====================================================================
    report "--- TEST 8: Overload detection ---";
      -- Set a new destination
      floor_request <= "1000"; -- Floor 8
    wait for CLK_PERIOD * 16; -- Wait for FSM to exit door sequence and enter MOVE_UP

    -- Assert weight sensor mid-travel
    weight_sensor <= '1';
    wait for CLK_PERIOD * 6;

    check(alarm_buzzer = '1' and motor_up = '0',
    "Overload detected: alarm on, motor stopped", "Overload not handled");

    weight_sensor <= '0';
    floor_request <= "0000";
    wait for CLK_PERIOD * 3;

    -- ====================================================================
    report "========================================";
    report "RESULTS: " & integer'image(n_pass) & " passed, " & integer'image(n_fail) & " failed.";
    report "========================================";
    std.env.finish;
  end process;

end architecture sim;
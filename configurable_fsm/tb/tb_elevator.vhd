-- ============================================================================
-- TESTBENCH: tb_elevator
-- Exercises elevator_wrapper through a set of representative scenarios:
--
--  1. Reset / power-on                         -> IDLE, all outputs low
--  2. Floor request (0->3): go_up events       -> MOVE_UP x3, DOOR_OPEN
--  3. Door-sensor hold (obstruction)           -> stays DOOR_OPEN
--  4. Door cleared                             -> back to IDLE
--  5. Floor request (3->1): go_down events     -> MOVE_DOWN x2, DOOR_OPEN
--  6. Emergency button mid-travel              -> forced IDLE, alarm clears
--  7. Same-floor request (no movement)         -> stays IDLE
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_elevator is
end entity tb_elevator;

architecture sim of tb_elevator is

  -- Clock period
  constant CLK_PERIOD : time := 10 ns;

  -- DUT ports
  signal clk           : std_logic                    := '0';
  signal reset         : std_logic                    := '0';
  signal floor_request : std_logic_vector(3 downto 0) := (others => '0');
  signal door_sensor   : std_logic                    := '0';
  signal door_clear    : std_logic                    := '0';
  signal weight_sensor : std_logic                    := '0';
  signal emergency_btn : std_logic                    := '0';
  signal motor_up      : std_logic;
  signal motor_down    : std_logic;
  signal door_open_out : std_logic;
  signal alarm         : std_logic;
  signal current_floor : std_logic_vector(3 downto 0);
  signal state_out     : std_logic_vector(4 downto 0);

  -- Test result tracking
  signal tests_run    : integer := 0;
  signal tests_passed : integer := 0;
  signal tests_failed : integer := 0;

  -- Helper: wait N rising clock edges
  procedure wait_cycles(n : in integer) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure;

  -- Helper: evaluate a single named check and print PASS / FAIL
  procedure check(
    tag      : in string;
    cond     : in boolean;
    pass_ctr : inout integer;
    fail_ctr : inout integer;
    run_ctr  : inout integer
  ) is
  begin
    run_ctr := run_ctr + 1;
    if cond then
      pass_ctr := pass_ctr + 1;
      report "  [PASS] " & tag severity NOTE;
    else
      fail_ctr := fail_ctr + 1;
      report "  [FAIL] " & tag severity ERROR;
    end if;
  end procedure;

begin

  -- -------------------------------------------------------------------------
  -- Clock generator
  -- -------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  -- -------------------------------------------------------------------------
  -- DUT instantiation
  -- -------------------------------------------------------------------------
  dut : entity work.elevator_wrapper
    port map
    (
      clk           => clk,
      reset         => reset,
      floor_request => floor_request,
      door_sensor   => door_sensor,
      door_clear    => door_clear,
      weight_sensor => weight_sensor,
      emergency_btn => emergency_btn,
      motor_up      => motor_up,
      motor_down    => motor_down,
      door_open_out => door_open_out,
      alarm         => alarm,
      current_floor => current_floor,
      state_out     => state_out
    );

  -- -------------------------------------------------------------------------
  -- Stimulus process
  -- -------------------------------------------------------------------------
  stimulus : process
    variable vrun    : integer := 0;
    variable vpassed : integer := 0;
    variable vfailed : integer := 0;
  begin

    -- =====================================================================
    -- TEST 1: Power-on reset
    -- Expected: state = IDLE (00000), all outputs '0'
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 1: Power-on reset" severity NOTE;
    report "  Expected: IDLE state, all outputs low" severity NOTE;
    reset <= '1';
    wait_cycles(4);
    reset <= '0';
    wait_cycles(2);

    check("State is IDLE (00000) after reset",
    state_out = "00000", vpassed, vfailed, vrun);
    check("motor_up is low after reset",
    motor_up = '0', vpassed, vfailed, vrun);
    check("motor_down is low after reset",
    motor_down = '0', vpassed, vfailed, vrun);
    check("door_open_out is low after reset",
    door_open_out = '0', vpassed, vfailed, vrun);

    -- =====================================================================
    -- TEST 2: Floor request 0 -> 3 (go_up x3, then arrive)
    -- Expected: IDLE -> MOVE_UP -> MOVE_UP -> MOVE_UP -> DOOR_OPEN
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 2: Floor request 0 -> 3 (go_up x3)" severity NOTE;
    report "  Expected: MOVE_UP x3, then DOOR_OPEN at floor 3" severity NOTE;
    floor_request <= "0011";
    wait_cycles(20);

    check("door_open_out asserted at floor 3",
    door_open_out = '1', vpassed, vfailed, vrun);
    check("State is EL_DOOR_OPEN (00011)",
    state_out = "00011", vpassed, vfailed, vrun);
    check("current_floor is 3 (0011)",
    current_floor = "0011", vpassed, vfailed, vrun);

    -- =====================================================================
    -- TEST 3: Door obstruction (hold door open)
    -- Expected: remain in DOOR_OPEN while door_sensor is asserted
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 3: Door obstruction detected" severity NOTE;
    report "  Expected: stay in DOOR_OPEN while obstruction present" severity NOTE;
    door_sensor <= '1';
    wait_cycles(6);

    check("State remains EL_DOOR_OPEN (00011) with obstruction",
    state_out = "00011", vpassed, vfailed, vrun);
    check("door_open_out still asserted during obstruction",
    door_open_out = '1', vpassed, vfailed, vrun);

    door_sensor <= '0';
    wait_cycles(2);

    -- =====================================================================
    -- TEST 4: Door cleared -> IDLE
    -- Expected: door_clear causes transition to IDLE
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 4: Door cleared" severity NOTE;
    report "  Expected: IDLE after door_clear asserted" severity NOTE;
    door_clear <= '1';
    wait_cycles(4);
    door_clear <= '0';
    wait_cycles(4);

    check("State is IDLE (00000) after door cleared",
    state_out = "00000", vpassed, vfailed, vrun);
    check("door_open_out deasserted after close",
    door_open_out = '0', vpassed, vfailed, vrun);

    -- =====================================================================
    -- TEST 5: Floor request 3 -> 1 (go_down x2, then arrive)
    -- Expected: IDLE -> MOVE_DOWN -> MOVE_DOWN -> DOOR_OPEN
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 5: Floor request 3 -> 1 (go_down x2)" severity NOTE;
    report "  Expected: MOVE_DOWN x2, then DOOR_OPEN at floor 1" severity NOTE;
    floor_request <= "0001";
    wait_cycles(20);

    check("door_open_out asserted at floor 1",
    door_open_out = '1', vpassed, vfailed, vrun);
    check("current_floor is 1 (0001)",
    current_floor = "0001", vpassed, vfailed, vrun);
    check("State is EL_DOOR_OPEN (00011)",
    state_out = "00011", vpassed, vfailed, vrun);

    -- Close door to return to IDLE for next test
    wait_cycles(2);
    door_clear <= '1';
    wait_cycles(4);
    door_clear <= '0';
    wait_cycles(6);

    -- =====================================================================
    -- TEST 6: Emergency button mid-travel
    -- Expected: FSM forced to IDLE, motor_up off
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 6: Emergency button during upward travel" severity NOTE;
    report "  Expected: IDLE state, motor_up off after emergency" severity NOTE;
    floor_request <= "0101";
    wait_cycles(8);
    emergency_btn <= '1';
    wait_cycles(4);
    emergency_btn <= '0';
    wait_cycles(4);

    check("State is IDLE (00000) after emergency",
    state_out = "00000", vpassed, vfailed, vrun);
    check("motor_up is off after emergency",
    motor_up = '0', vpassed, vfailed, vrun);
    check("motor_down is off after emergency",
    motor_down = '0', vpassed, vfailed, vrun);

    -- =====================================================================
    -- TEST 7: Same-floor request (no movement expected)
    -- Expected: motors stay off when target = current floor
    -- =====================================================================
    report "----------------------------------------" SEVERITY NOTE;
      report "TEST 7: Same-floor request (no movement)" severity NOTE;
    report "  Expected: motors stay off for same-floor request" severity NOTE;
    floor_request <= current_floor;
    wait_cycles(10);

    check("motor_up off for same-floor request",
    motor_up = '0', vpassed, vfailed, vrun);
    check("motor_down off for same-floor request",
    motor_down = '0', vpassed, vfailed, vrun);
    check("State remains IDLE (00000)",
    state_out = "00000", vpassed, vfailed, vrun);

    -- =====================================================================
    -- Summary
    -- =====================================================================
    tests_run    <= vrun;
    tests_passed <= vpassed;
    tests_failed <= vfailed;

    report "========================================" severity NOTE;
    report "RESULTS: " &
      integer'IMAGE(vpassed) & " passed, " &
      integer'IMAGE(vfailed) & " failed, " &
      integer'IMAGE(vrun) & " total"
      severity NOTE;
    if vfailed = 0 then
      report "STATUS: ALL TESTS PASSED" severity NOTE;
    else
      report "STATUS: " & integer'IMAGE(vfailed) & " TEST(S) FAILED"
        severity ERROR;
    end if;
    report "========================================" severity NOTE;

    wait;

  end process stimulus;

end architecture sim;
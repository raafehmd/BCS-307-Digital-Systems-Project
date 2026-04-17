-- ============================================================================
-- ELEVATOR WRAPPER
-- Application wrapper for the configurable FSM core
--
-- Config ID : "10" (Elevator)
-- States    : EL_IDLE(0), EL_MOVE_UP(1), EL_MOVE_DOWN(2),
--             EL_DOOR_OPEN(3), EL_DOOR_CLOSE(4)
--
-- Event Bit Map (10-bit event_code):
--   Bit 0 : go_up         (derived: target_floor > current_floor)
--   Bit 1 : go_down       (derived: target_floor < current_floor)
--   Bit 2 : arrived       (derived: current_floor = target_floor while moving)
--   Bit 3 : door_clear    (physical input – door path clear, close door)
--   Bit 4 : door_sensor   (physical input – obstruction detected, hold open)
--   Bit 5 : weight_sensor (physical input – overload detected)
--   Bit 6 : emergency_btn (physical input – interrupt, forces IDLE)
--   Bits 7-9: unused (tied low)
--
-- Output Action Map (16-bit output_action from FSM core):
--   Bit 0 : motor_up   (drive motor upward)
--   Bit 1 : motor_down (drive motor downward)
--   Bit 2 : door_open  (open/hold door actuator)
--   Bit 3 : alarm      (emergency/overload alarm)
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity elevator_wrapper is
  port (
    clk   : in std_logic;
    reset : in std_logic;
    -- Physical inputs
    floor_request : in std_logic_vector(3 downto 0); -- Target floor (0-9 via 4-bit BCD)
    door_sensor   : in std_logic; -- '1' = obstruction present (hold door open)
    door_clear    : in std_logic; -- '1' = path clear, safe to close
    weight_sensor : in std_logic; -- '1' = overload detected
    emergency_btn : in std_logic; -- '1' = emergency (interrupt)
    -- Physical outputs
    motor_up      : out std_logic;
    motor_down    : out std_logic;
    door_open_out : out std_logic;
    alarm         : out std_logic;
    -- Debug / status
    current_floor : out std_logic_vector(3 downto 0);
    state_out     : out std_logic_vector(4 downto 0)
  );
end entity elevator_wrapper;

architecture structural of elevator_wrapper is

  -- -------------------------------------------------------------------------
  -- Configuration constant
  -- -------------------------------------------------------------------------
  constant EL_CONFIG_ID : std_logic_vector(1 downto 0) := "10";

  -- -------------------------------------------------------------------------
  -- Emergency interrupt event code (bit 6 high)
  -- -------------------------------------------------------------------------
  constant EV_EMERGENCY : std_logic_vector(9 downto 0) := "0001000000"; -- bit 6

  -- -------------------------------------------------------------------------
  -- Internal signals – FSM interface
  -- -------------------------------------------------------------------------
  signal event_code      : std_logic_vector(9 downto 0) := (others => '0');
  signal config_data     : std_logic_vector(31 downto 0);
  signal config_addr     : std_logic_vector(16 downto 0);
  signal output_action   : std_logic_vector(15 downto 0);
  signal state_code      : std_logic_vector(4 downto 0);
  signal output_valid    : std_logic;
  signal fsm_busy        : std_logic;
  signal timer_start_sig : std_logic; -- unused at wrapper level (no timer here)
  signal timer_reset_sig : std_logic; -- unused at wrapper level

  -- -------------------------------------------------------------------------
  -- Floor tracking registers (wrapper responsibility, not in FSM core)
  -- -------------------------------------------------------------------------
  signal current_floor_reg : std_logic_vector(3 downto 0) := (others => '0');
  signal target_floor_reg  : std_logic_vector(3 downto 0) := (others => '0');

  -- -------------------------------------------------------------------------
  -- Derived movement signals
  -- -------------------------------------------------------------------------
  signal go_up   : std_logic;
  signal go_down : std_logic;
  signal arrived : std_logic;

  -- -------------------------------------------------------------------------
  -- FSM state constants (mirrors config_rom.vhd)
  -- -------------------------------------------------------------------------
  constant EL_IDLE       : std_logic_vector(4 downto 0) := "00000";
  constant EL_MOVE_UP    : std_logic_vector(4 downto 0) := "00001";
  constant EL_MOVE_DOWN  : std_logic_vector(4 downto 0) := "00010";
  constant EL_DOOR_OPEN  : std_logic_vector(4 downto 0) := "00011";
  constant EL_DOOR_CLOSE : std_logic_vector(4 downto 0) := "00100";

begin

  -- =========================================================================
  -- Floor register update
  -- When a new floor request arrives and the cabin is idle, latch it as the
  -- target.  current_floor_reg is updated by the wrapper when the FSM core
  -- signals MOVE_UP / MOVE_DOWN and the arrived event fires.
  -- =========================================================================
  floor_tracking : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_floor_reg <= (others => '0');
        target_floor_reg  <= (others => '0');
      else
        -- Always track floor_request while idle.
        -- Unconditionally latching (including same-floor) clears any
        -- stale target left behind by an emergency abort mid-travel,
        -- preventing spurious go_up/go_down pulses (S7 fix).
        if state_code = EL_IDLE then
          target_floor_reg <= floor_request;
        end if;

        -- Advance current floor while moving (one floor per FSM cycle)
        if state_code = EL_MOVE_UP and
          current_floor_reg /= target_floor_reg then
          current_floor_reg <=
            std_logic_vector(unsigned(current_floor_reg) + 1);
        elsif state_code = EL_MOVE_DOWN and
          current_floor_reg /= target_floor_reg then
          current_floor_reg <=
            std_logic_vector(unsigned(current_floor_reg) - 1);
        end if;
      end if;
    end if;
  end process floor_tracking;

  -- =========================================================================
  -- Derived event signals (combinatorial)
  -- =========================================================================
  go_up <= '1' when unsigned(target_floor_reg) > unsigned(current_floor_reg)
    and state_code = EL_IDLE
    else
    '0';

  go_down <= '1' when unsigned(target_floor_reg) < unsigned(current_floor_reg)
    and state_code = EL_IDLE
    else
    '0';

  arrived <= '1' when current_floor_reg = target_floor_reg
    and (state_code = EL_MOVE_UP or state_code = EL_MOVE_DOWN)
    else
    '0';

  -- =========================================================================
  -- Input resolver: produces a single 10-bit event_code per cycle.
  -- Priority (highest first):
  --   1. emergency_btn  (bit 6) – interrupt
  --   2. door_sensor    (bit 4) – hold door open
  --   3. door_clear     (bit 3) – close door
  --   4. weight_sensor  (bit 5) – overload
  --   5. arrived        (bit 2) – floor reached
  --   6. go_up          (bit 0) – start upward movement
  --   7. go_down        (bit 1) – start downward movement
  -- =========================================================================
  input_resolver : process (emergency_btn, door_sensor, door_clear,
    weight_sensor, arrived, go_up, go_down, fsm_busy)
  begin
    event_code <= (others => '0');
    if fsm_busy = '0' then
      if emergency_btn = '1' then
        event_code <= "0001000000"; -- bit 6
      elsif door_sensor = '1' then
        event_code <= "0000010000"; -- bit 4
      elsif door_clear = '1' then
        event_code <= "0000001000"; -- bit 3
      elsif weight_sensor = '1' then
        event_code <= "0000100000"; -- bit 5
      elsif arrived = '1' then
        event_code <= "0000000100"; -- bit 2
      elsif go_up = '1' then
        event_code <= "0000000001"; -- bit 0
      elsif go_down = '1' then
        event_code <= "0000000010"; -- bit 1
      end if;
    end if;
  end process input_resolver;

  -- =========================================================================
  -- Component instantiations
  -- =========================================================================

  -- Configuration ROM
  rom_inst : entity work.config_rom
    port map
    (
      clk      => clk,
      addr     => config_addr,
      data_out => config_data
    );

  -- Generic FSM core
  fsm_core : entity work.generic_fsm
    port map
    (
      clk             => clk,
      reset           => reset,
      event_code      => event_code,
      config_data     => config_data,
      config_id       => EL_CONFIG_ID,
      interrupt_event => EV_EMERGENCY,
      state_code      => state_code,
      output_action   => output_action,
      config_addr     => config_addr,
      output_valid    => output_valid,
      fsm_busy        => fsm_busy,
      timer_start_out => timer_start_sig,
      timer_reset_out => timer_reset_sig
    );

  -- =========================================================================
  -- Output encoder
  -- =========================================================================
  motor_up      <= output_action(0);
  motor_down    <= output_action(1);
  door_open_out <= output_action(2);
  alarm         <= output_action(3);

  -- Status / debug
  current_floor <= current_floor_reg;
  state_out     <= state_code;

end architecture structural;
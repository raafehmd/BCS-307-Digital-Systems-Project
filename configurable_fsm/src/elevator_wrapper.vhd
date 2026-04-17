-- ============================================================================
-- ELEVATOR WRAPPER
-- Application wrapper for configurable FSM core
--
-- Reference: Configurable FSM Master Doc, Sections 5.3, 7.4.1
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity elevator_top is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    -- Elevator Inputs
    floor_request : in std_logic_vector(3 downto 0);
    door_sensor   : in std_logic;
    weight_sensor : in std_logic;
    emergency_btn : in std_logic;

    -- Elevator Outputs
    motor_up        : out std_logic;
    motor_down      : out std_logic;
    door_open       : out std_logic;
    alarm_buzzer    : out std_logic;
    emergency_light : out std_logic;
    floor_display   : out std_logic_vector(3 downto 0)
  );
end entity elevator_top;

architecture behavioral of elevator_top is

  -- Constants
  constant EL_CONFIG_ID       : std_logic_vector(1 downto 0) := "10";
  constant EL_INTERRUPT_EVENT : std_logic_vector(9 downto 0) := "0001000000";
  constant EL_IDLE_STATE      : std_logic_vector(4 downto 0) := "00000";

  -- Generic FSM interface signals
  signal event_code    : std_logic_vector(9 downto 0);
  signal output_action : std_logic_vector(15 downto 0);
  signal config_data   : std_logic_vector(31 downto 0);
  signal config_addr   : std_logic_vector(16 downto 0);
  signal state_code    : std_logic_vector(4 downto 0);
  signal output_valid  : std_logic;
  signal fsm_busy      : std_logic;

  -- Floor tracking registers
  signal current_floor : integer range 1 to 11 := 1;
  signal target_floor  : integer range 1 to 11 := 1;

  -- Internal signals for output actions
  signal motor_up_i   : std_logic;
  signal motor_down_i : std_logic;

  -- Abort detection
  signal prev_state_code : std_logic_vector(4 downto 0);

begin

  -- ========================================================================
  -- 1. Input Decoder (Priority Encoder)
  -- ========================================================================
  -- Resolves physical inputs and floor comparisons into a single event_code.
  input_decoder : process (current_floor, target_floor, door_sensor, weight_sensor, emergency_btn, fsm_busy)
  begin
    event_code <= (others => '0');

    -- Only accept new events when pipeline is not busy
    if fsm_busy = '0' then
      if emergency_btn = '1' then
        event_code <= EL_INTERRUPT_EVENT;
      elsif weight_sensor = '1' then
        event_code(5) <= '1';
      elsif door_sensor = '1' then
        event_code(4) <= '1';
      elsif target_floor > current_floor then
        event_code(0) <= '1'; -- go_up
      elsif target_floor < current_floor then
        event_code(1) <= '1'; -- go_down
      elsif target_floor = current_floor then
        event_code(2) <= '1'; -- arrived
      end if;
    end if;
  end process input_decoder;

  -- ========================================================================
  -- 2. Floor Latching Logic
  -- ========================================================================
  floor_latch : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        target_floor                                                   <= 1;
      elsif unsigned(floor_request) >= 1 and unsigned(floor_request) <= 11 then
        target_floor                                                   <= to_integer(unsigned(floor_request));
      end if;
    end if;
  end process floor_latch;

  -- ========================================================================
  -- 3. Floor Counter Logic
  -- ========================================================================
  floor_counter : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_floor <= 1;
      elsif motor_up_i = '1' and current_floor < 11 then
        current_floor <= current_floor + 1;
      elsif motor_down_i = '1' and current_floor > 1 then
        current_floor <= current_floor - 1;
      end if;
    end if;
  end process floor_counter;

  -- ========================================================================
  -- 4. Configuration ROM Instantiation
  -- ========================================================================
  rom_inst : entity work.config_rom
    port map
    (
      clk      => clk,
      addr     => config_addr,
      data_out => config_data
    );

  -- ========================================================================
  -- 5. Generic FSM Core Instantiation
  -- ========================================================================
  fsm_core : entity work.generic_fsm
    port map
    (
      clk             => clk,
      reset           => reset,
      event_code      => event_code,
      config_data     => config_data,
      config_id       => EL_CONFIG_ID,
      interrupt_event => EL_INTERRUPT_EVENT,
      state_code      => state_code,
      output_action   => output_action,
      config_addr     => config_addr,
      output_valid    => output_valid,
      fsm_busy        => fsm_busy,
      timer_start_out => open,
      timer_reset_out => open
    );

  -- ========================================================================
  -- 6. Output Encoder
  -- ========================================================================
  output_encoder : process (output_action, current_floor, weight_sensor, state_code)
  begin
    motor_up_i   <= output_action(0);
    motor_down_i <= output_action(1);

    motor_up   <= output_action(0);
    motor_down <= output_action(1);
    door_open  <= output_action(2);

    -- Overload detection: Assert independently of output_action when not idle
    if weight_sensor = '1' and state_code /= EL_IDLE_STATE then
      alarm_buzzer <= '1';
    else
      alarm_buzzer <= output_action(3);
    end if;

    floor_display <= std_logic_vector(to_unsigned(current_floor, 4));
  end process output_encoder;

  -- ========================================================================
  -- 7. Emergency Light Abort Detection
  -- ========================================================================
  -- Drives the emergency light independently since ROM is bypassed on interrupt
  abort_detect : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        prev_state_code <= EL_IDLE_STATE;
        emergency_light <= '0';
      else
        prev_state_code <= state_code;

        -- Assert for exactly 1 cycle when interrupted into IDLE
        if (prev_state_code /= EL_IDLE_STATE) and (state_code = EL_IDLE_STATE) and (emergency_btn = '1') then
          emergency_light <= '1';
        else
          emergency_light <= '0';
        end if;
      end if;
    end if;
  end process abort_detect;

end architecture behavioral;
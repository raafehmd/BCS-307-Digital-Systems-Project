-- ============================================================================
-- VENDING MACHINE WRAPPER
-- Application wrapper for configurable FSM core
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity vending_wrapper is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;

    coin_insert   : in  std_logic;
    selection_btn : in  std_logic_vector(1 downto 0);
    item_empty    : in  std_logic;
    dispense_done : in  std_logic;
    cancel_btn    : in  std_logic;
    change_done   : in  std_logic;

    dispense_motor : out std_logic;
    change_return  : out std_logic;
    display_msg    : out std_logic_vector(7 downto 0);

    state_code    : out std_logic_vector(4 downto 0);
    fsm_busy      : out std_logic;
    output_valid  : out std_logic
  );
end entity vending_wrapper;

architecture rtl of vending_wrapper is

  constant VM_CONFIG_ID       : std_logic_vector(1 downto 0) := "01";
  constant VM_INTERRUPT_EVENT : std_logic_vector(9 downto 0) := "0000100000";  -- bit 5
  constant VM_STATE_IDLE      : std_logic_vector(4 downto 0) := "00000";
  constant VM_STATE_COLLECT   : std_logic_vector(4 downto 0) := "00010";

  signal event_code      : std_logic_vector(9 downto 0);
  signal config_addr     : std_logic_vector(16 downto 0);
  signal config_data     : std_logic_vector(31 downto 0);
  signal output_action   : std_logic_vector(15 downto 0);
  signal state_code_i    : std_logic_vector(4 downto 0);
  signal fsm_busy_i      : std_logic;
  signal output_valid_i  : std_logic;
  signal ts_unused       : std_logic;
  signal tr_unused       : std_logic;

  signal prev_state       : std_logic_vector(4 downto 0) := (others => '0');
  signal int_change_pulse : std_logic := '0';

begin

  input_decoder : process(coin_insert, selection_btn, item_empty,
                          dispense_done, cancel_btn, change_done,
                          fsm_busy_i)
  begin
    event_code <= (others => '0');

    if fsm_busy_i = '0' then
      if cancel_btn = '1' then
        event_code <= VM_INTERRUPT_EVENT;
      elsif change_done = '1' then
        event_code(6) <= '1';
      elsif dispense_done = '1' then
        event_code(4) <= '1';
      elsif item_empty = '1' then
        event_code(3) <= '1';
      elsif selection_btn /= "00" then
        event_code(2 downto 1) <= selection_btn;
      elsif coin_insert = '1' then
        event_code(0) <= '1';
      end if;
    end if;
  end process input_decoder;

  interrupt_return_detect : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        prev_state       <= (others => '0');
        int_change_pulse <= '0';
      else
        int_change_pulse <= '0';

        if prev_state = VM_STATE_COLLECT and state_code_i = VM_STATE_IDLE then
          int_change_pulse <= '1';
        end if;

        prev_state <= state_code_i;
      end if;
    end if;
  end process interrupt_return_detect;

  dispense_motor <= output_action(0);
  change_return  <= output_action(1) or int_change_pulse;
  display_msg    <= output_action(9 downto 2);

  state_code   <= state_code_i;
  fsm_busy     <= fsm_busy_i;
  output_valid <= output_valid_i;

  rom_inst : entity work.config_rom
    port map (
      clk      => clk,
      addr     => config_addr,
      data_out => config_data
    );

  fsm_core : entity work.generic_fsm
    port map (
      clk             => clk,
      reset           => rst,
      event_code      => event_code,
      config_data     => config_data,
      config_id       => VM_CONFIG_ID,
      interrupt_event => VM_INTERRUPT_EVENT,
      state_code      => state_code_i,
      output_action   => output_action,
      config_addr     => config_addr,
      output_valid    => output_valid_i,
      fsm_busy        => fsm_busy_i,
      timer_start_out => ts_unused,
      timer_reset_out => tr_unused
    );

end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;

entity tb_vending is
end entity tb_vending;

architecture sim of tb_vending is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
begin
  clk <= not clk after 5 ns;

  dut: entity work.vending_wrapper
    port map (
      clk => clk,
      rst => rst
    );

  process
  begin
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait for 100 ns;
    wait;
  end process;
end architecture sim;

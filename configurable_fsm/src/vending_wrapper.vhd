library ieee;
use ieee.std_logic_1164.all;

entity vending_wrapper is
  port (
    clk : in std_logic;
    rst : in std_logic
  );
end entity vending_wrapper;

architecture rtl of vending_wrapper is
begin
  -- TODO: Instantiate generic_fsm for vending machine application.
end architecture rtl;

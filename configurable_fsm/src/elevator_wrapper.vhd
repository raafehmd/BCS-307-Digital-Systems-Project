library ieee;
use ieee.std_logic_1164.all;

entity elevator_wrapper is
  port (
    clk : in std_logic;
    rst : in std_logic
  );
end entity elevator_wrapper;

architecture rtl of elevator_wrapper is
begin
  -- TODO: Instantiate generic_fsm for elevator application.
end architecture rtl;

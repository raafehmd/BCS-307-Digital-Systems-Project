library ieee;
use ieee.std_logic_1164.all;

entity serial_wrapper is
  port (
    clk : in std_logic;
    rst : in std_logic
  );
end entity serial_wrapper;

architecture rtl of serial_wrapper is
begin
  -- TODO: Instantiate generic_fsm for serial protocol application.
end architecture rtl;

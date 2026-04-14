LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY config_rom IS
PORT (
    clk      : IN  STD_LOGIC;
    addr     : IN  STD_LOGIC_VECTOR(16 DOWNTO 0);
    data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
);
END ENTITY config_rom;

ARCHITECTURE behavioral OF config_rom IS
    TYPE rom_array IS ARRAY (0 TO 32767) OF STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Helper function to build ROM data word
    FUNCTION rom_data(next_state    : STD_LOGIC_VECTOR(4 DOWNTO 0);
                     output_action : STD_LOGIC_VECTOR(15 DOWNTO 0)) 
                    RETURN STD_LOGIC_VECTOR IS
    BEGIN
        -- [31:29]=000, [28:24]=next_state, [23:8]=output_action, 
        -- [7:4]=0000, [3]=timer_reset=1, [2]=timer_start=1, [1:0]=00
        RETURN "000" & next_state & output_action & "0000" & "1100";
    END FUNCTION;

    -- Pre-calculated addresses for Traffic Light (Config ID 00)
    CONSTANT ADDR_IDLE_CAR     : INTEGER := 2;      
    CONSTANT ADDR_IDLE_PED     : INTEGER := 1;      
    CONSTANT ADDR_RED_TIMER    : INTEGER := 1028;   
    CONSTANT ADDR_RED_PED      : INTEGER := 1025;   
    CONSTANT ADDR_GREEN_TIMER  : INTEGER := 2052;   
    CONSTANT ADDR_GREEN_PED    : INTEGER := 2049;   
    CONSTANT ADDR_YELLOW_TIMER : INTEGER := 3076;   
    CONSTANT ADDR_PEDW_TIMER   : INTEGER := 4100;   
    CONSTANT ADDR_PEDC_TIMER   : INTEGER := 5124;   

    CONSTANT traffic_rom : rom_array := (
        ADDR_IDLE_CAR      => rom_data("00001", "0000000000000001"),
        ADDR_IDLE_PED      => rom_data("00001", "0000000000000001"),
        ADDR_RED_TIMER     => rom_data("00010", "0000000000000100"),
        ADDR_RED_PED       => rom_data("00100", "0000000000000001"),
        ADDR_GREEN_TIMER   => rom_data("00011", "0000000000000010"),
        ADDR_GREEN_PED     => rom_data("00100", "0000000000000001"),
        ADDR_YELLOW_TIMER  => rom_data("00001", "0000000000000001"),
        ADDR_PEDW_TIMER    => rom_data("00101", "0000000000001001"),
        ADDR_PEDC_TIMER    => rom_data("00001", "0000000000000001"),
        OTHERS             => (OTHERS => '0')
    );

    CONSTANT vending_rom  : rom_array := (OTHERS => (OTHERS => '0'));
    CONSTANT elevator_rom : rom_array := (OTHERS => (OTHERS => '0'));
    CONSTANT serial_rom   : rom_array := (OTHERS => (OTHERS => '0'));

BEGIN
    read_process: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            CASE addr(16 DOWNTO 15) IS
                WHEN "00" => 
                    data_out <= traffic_rom(to_integer(unsigned(addr(14 DOWNTO 0))));
                WHEN "01" => 
                    data_out <= vending_rom(to_integer(unsigned(addr(14 DOWNTO 0))));
                WHEN "10" => 
                    data_out <= elevator_rom(to_integer(unsigned(addr(14 DOWNTO 0))));
                WHEN "11" => 
                    data_out <= serial_rom(to_integer(unsigned(addr(14 DOWNTO 0))));
                WHEN OTHERS => 
                    data_out <= (OTHERS => '0');
            END CASE;
        END IF;
    END PROCESS read_process;
END ARCHITECTURE behavioral;
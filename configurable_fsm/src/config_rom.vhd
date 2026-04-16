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
    -- Allows flexible configuration of all control flags
    -- Format: [31:29]=unused, [28:24]=next_state, [23:8]=output_action,
    --         [7:4]=unused, [3]=timer_reset, [2]=timer_start, 
    --         [1]=interrupt_en, [0]=hold_state
    FUNCTION rom_data(
        next_state    : STD_LOGIC_VECTOR(4 DOWNTO 0);
        output_action : STD_LOGIC_VECTOR(15 DOWNTO 0);
        hold_state    : STD_LOGIC;
        interrupt_en  : STD_LOGIC;
        timer_start   : STD_LOGIC;
        timer_reset   : STD_LOGIC
    ) RETURN STD_LOGIC_VECTOR IS
    BEGIN
        RETURN "000" & next_state & output_action & "0000" 
            & timer_reset & timer_start & interrupt_en & hold_state;
    END FUNCTION rom_data;

    -- Pre-calculated addresses for Traffic Light (Config ID = "00")
    -- Address format: config_id[16:15] & state[14:10] & event[9:0]
    -- For config_id = "00", addresses range from 0 to 32767
    
    -- State definitions
    CONSTANT STATE_IDLE    : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
    CONSTANT STATE_RED     : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00001";
    CONSTANT STATE_GREEN   : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00010";
    CONSTANT STATE_YELLOW  : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00011";
    CONSTANT STATE_PED_WAIT: STD_LOGIC_VECTOR(4 DOWNTO 0) := "00100";
    CONSTANT STATE_PED_CROSS:STD_LOGIC_VECTOR(4 DOWNTO 0) := "00101";
    
    -- Event codes
    CONSTANT EVENT_CAR_ARRIVAL  : INTEGER := 1;
    CONSTANT EVENT_PED_REQUEST  : INTEGER := 2;
    CONSTANT EVENT_TIMER_EXPIRE : INTEGER := 3;
    CONSTANT EVENT_INTERRUPT    : INTEGER := 0;
    
    -- Output action codes (16-bit masks for traffic light signals)
    CONSTANT OUT_RED_ON      : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0001";
    CONSTANT OUT_GREEN_ON    : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0002";
    CONSTANT OUT_YELLOW_ON   : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0004";
    CONSTANT OUT_PED_WALK    : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0008";
    CONSTANT OUT_PED_DONT    : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0010";

    -- Traffic Light ROM (Config ID = "00")
    CONSTANT traffic_rom : rom_array := (
        -- IDLE State: Wait for car or pedestrian
        -- Addr = 0x00000 (config_id=00, state=00000, event=0000)
        0 => rom_data(STATE_IDLE, OUT_RED_ON, '1', '0', '0', '0'),
        
        -- RED state, CAR_ARRIVAL event (addr = 0x00100 + 1)
        -- => Transition to GREEN with timer enabled
        257 => rom_data(STATE_GREEN, OUT_GREEN_ON, '0', '0', '1', '1'),
        
        -- RED state, PED_REQUEST event (addr = 0x00200 + 2)
        -- => Go to PED_WAIT state with hold (acknowledge request)
        514 => rom_data(STATE_PED_WAIT, OUT_PED_DONT, '0', '0', '0', '0'),
        
        -- RED state, TIMER_EXPIRE event (addr = 0x00300 + 3)
        -- => Stay in RED until event clears
        771 => rom_data(STATE_RED, OUT_RED_ON, '1', '0', '0', '0'),
        
        -- GREEN state, CAR_ARRIVAL event (addr = 0x08100 + 1)
        -- => Stay in GREEN with timer active
        2049 => rom_data(STATE_GREEN, OUT_GREEN_ON, '0', '0', '1', '1'),
        
        -- GREEN state, PED_REQUEST event (addr = 0x08200 + 2)
        -- => Move to YELLOW state to begin transition
        2306 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '0', '0', '1', '1'),
        
        -- GREEN state, TIMER_EXPIRE event (addr = 0x08300 + 3)
        -- => Transition to YELLOW (green time exhausted)
        2563 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '0', '0', '1', '1'),
        
        -- YELLOW state, CAR_ARRIVAL event (addr = 0x10100 + 1)
        -- => Stay in YELLOW (timer must expire first)
        4097 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '1', '0', '0', '0'),
        
        -- YELLOW state, PED_REQUEST event (addr = 0x10200 + 2)
        -- => Stay in YELLOW (non-blocking)
        4354 => rom_data(STATE_YELLOW, OUT_YELLOW_ON, '1', '0', '0', '0'),
        
        -- YELLOW state, TIMER_EXPIRE event (addr = 0x10300 + 3)
        -- => Return to RED after yellow timeout
        4611 => rom_data(STATE_RED, OUT_RED_ON, '0', '0', '1', '1'),
        
        -- PED_WAIT state, TIMER_EXPIRE event (addr = 0x18300 + 3)
        -- => Transition to PED_CROSS for pedestrian crossing
        6403 => rom_data(STATE_PED_CROSS, OUT_PED_WALK, '0', '0', '1', '1'),
        
        -- PED_CROSS state, TIMER_EXPIRE event (addr = 0x20300 + 3)
        -- => Return to IDLE after pedestrian crosses
        8195 => rom_data(STATE_IDLE, OUT_RED_ON, '0', '0', '0', '0'),
        
        -- Default entries (undefined states/events return 0 = hold state, no action)
        OTHERS => (OTHERS => '0')
    );

    -- Vending Machine ROM (Config ID = "01") - Placeholder
    -- To be populated with vending machine state transitions
    CONSTANT vending_rom  : rom_array := (OTHERS => (OTHERS => '0'));

    -- Elevator ROM (Config ID = "10") - Placeholder
    -- To be populated with elevator controller state transitions
    CONSTANT elevator_rom : rom_array := (OTHERS => (OTHERS => '0'));


    -- Serial Protocol ROM (Config ID = "11")
    CONSTANT serial_rom : rom_array := (
        256   => rom_data("00001", x"0000", '0', '0', '0', '0'), -- SP_IDLE    + rx_valid -> SP_START
        1280  => rom_data("00010", x"0000", '0', '0', '0', '0'), -- SP_START   + rx_valid -> SP_RX_BIT0
        2304  => rom_data("00011", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT0 + rx_valid -> SP_RX_BIT1
        3328  => rom_data("00100", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT1 + rx_valid -> SP_RX_BIT2
        4352  => rom_data("00101", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT2 + rx_valid -> SP_RX_BIT3
        5376  => rom_data("00110", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT3 + rx_valid -> SP_RX_BIT4
        6400  => rom_data("00111", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT4 + rx_valid -> SP_RX_BIT5
        7424  => rom_data("01000", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT5 + rx_valid -> SP_RX_BIT6
        8448  => rom_data("01001", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT6 + rx_valid -> SP_RX_BIT7
        9472  => rom_data("01010", x"0000", '0', '1', '0', '0'), -- SP_RX_BIT7 + rx_valid -> SP_STOP
        10496 => rom_data("01011", x"0100", '0', '1', '0', '0'), -- SP_STOP    + rx_valid -> SP_COMPLETE (tx_enable=1)
        11776 => rom_data("00000", x"0000", '0', '0', '0', '0'), -- SP_COMPLETE+ tx_ready -> SP_IDLE
        OTHERS => (OTHERS => '0')
    );

BEGIN
    -- Synchronous ROM read process
    -- On each rising clock edge, output the ROM data at the given address
    read_process: PROCESS(clk)
        VARIABLE addr_int : INTEGER;
    BEGIN
        IF rising_edge(clk) THEN
            addr_int := to_integer(unsigned(addr(14 DOWNTO 0)));
            
            -- Decode config_id (upper 2 bits of address) to select ROM
            CASE addr(16 DOWNTO 15) IS
                WHEN "00" => 
                    -- Traffic Light Config
                    data_out <= traffic_rom(addr_int);
                    
                WHEN "01" => 
                    -- Vending Machine Config
                    data_out <= vending_rom(addr_int);
                    
                WHEN "10" => 
                    -- Elevator Config
                    data_out <= elevator_rom(addr_int);
                    
                WHEN "11" => 
                    -- Serial Protocol Config
                    data_out <= serial_rom(addr_int);
                    
                WHEN OTHERS => 
                    -- Safety fallback
                    data_out <= (OTHERS => '0');
            END CASE;
        END IF;
    END PROCESS read_process;
    
END ARCHITECTURE behavioral;
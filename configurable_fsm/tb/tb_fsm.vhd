LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_fsm IS
END ENTITY tb_fsm;

ARCHITECTURE test OF tb_fsm IS
    
    COMPONENT generic_fsm IS
        PORT (
            clk             : IN  STD_LOGIC;
            reset           : IN  STD_LOGIC;
            event_code      : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            config_data     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            config_id       : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            interrupt_event : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
            state_code      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            output_action   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            config_addr     : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
            output_valid    : OUT STD_LOGIC;
            fsm_busy        : OUT STD_LOGIC;
            timer_start_out : OUT STD_LOGIC;
            timer_reset_out : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT config_rom IS
        PORT (
            clk      : IN  STD_LOGIC;
            addr     : IN  STD_LOGIC_VECTOR(16 DOWNTO 0);
            data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;
    
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    SIGNAL event_code : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL config_data : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL config_id : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL interrupt_event : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL state_code : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL output_action : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL config_addr : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL output_valid : STD_LOGIC;
    SIGNAL fsm_busy : STD_LOGIC;
    SIGNAL timer_start_out : STD_LOGIC;
    SIGNAL timer_reset_out : STD_LOGIC;
    SIGNAL rom_data : STD_LOGIC_VECTOR(31 DOWNTO 0);

BEGIN
    
    fsm_inst: generic_fsm PORT MAP (
        clk => clk,
        reset => reset,
        event_code => event_code,
        config_data => config_data,
        config_id => config_id,
        interrupt_event => interrupt_event,
        state_code => state_code,
        output_action => output_action,
        config_addr => config_addr,
        output_valid => output_valid,
        fsm_busy => fsm_busy,
        timer_start_out => timer_start_out,
        timer_reset_out => timer_reset_out
    );
    
    rom_inst: config_rom PORT MAP (
        clk => clk,
        addr => config_addr,
        data_out => rom_data
    );
    
    config_data <= rom_data;
    
    clk <= NOT clk AFTER 5 ns;
    
    PROCESS
    BEGIN
        REPORT "========================================" SEVERITY NOTE;
        REPORT "FSM SIMPLE TEST" SEVERITY NOTE;
        REPORT "========================================" SEVERITY NOTE;
        
        REPORT "Test 1: Reset" SEVERITY NOTE;
        reset <= '1';
        config_id <= "00";
        WAIT FOR 20 ns;
        
        IF state_code = "00000" THEN
            REPORT "PASS: Reset forced state to IDLE (00000)" SEVERITY NOTE;
        ELSE
            REPORT "FAIL: Reset did not set IDLE state" SEVERITY ERROR;
        END IF;
        
        reset <= '0';
        WAIT FOR 10 ns;
        
        REPORT "Test 2: Event Capture" SEVERITY NOTE;
        event_code <= "0000000001";
        WAIT FOR 10 ns;
        
        IF fsm_busy = '1' THEN
            REPORT "PASS: FSM busy asserted on event" SEVERITY NOTE;
        ELSE
            REPORT "FAIL: FSM busy did not assert" SEVERITY ERROR;
        END IF;
        
        WAIT FOR 10 ns;
        
        REPORT "Test 3: ROM Address Computation" SEVERITY NOTE;
        IF config_addr = ("00" & "00000" & "0000000001") THEN
            REPORT "PASS: ROM address correct (config_id & state & event)" SEVERITY NOTE;
        ELSE
            REPORT "FAIL: ROM address incorrect" SEVERITY ERROR;
        END IF;
        
        event_code <= (OTHERS => '0');
        WAIT FOR 30 ns;
        
        REPORT "Test 4: ROM Data Reception" SEVERITY NOTE;
        IF rom_data /= (rom_data'RANGE => '0') THEN
            REPORT "PASS: ROM data received: " & INTEGER'IMAGE(to_integer(unsigned(rom_data(28 DOWNTO 24)))) SEVERITY NOTE;
        ELSE
            REPORT "FAIL: ROM data all zeros" SEVERITY ERROR;
        END IF;
        
        WAIT FOR 20 ns;
        
        REPORT "Test 5: State Update Check" SEVERITY NOTE;
        REPORT "Current State: " & INTEGER'IMAGE(to_integer(unsigned(state_code))) SEVERITY NOTE;
        REPORT "Output Action: " & INTEGER'IMAGE(to_integer(unsigned(output_action))) SEVERITY NOTE;
        REPORT "Output Valid: " & STD_LOGIC'IMAGE(output_valid) SEVERITY NOTE;
        REPORT "Timer Start: " & STD_LOGIC'IMAGE(timer_start_out) SEVERITY NOTE;
        REPORT "Timer Reset: " & STD_LOGIC'IMAGE(timer_reset_out) SEVERITY NOTE;
        
        WAIT FOR 50 ns;
        
        REPORT "========================================" SEVERITY NOTE;
        REPORT "FSM SIMPLE TEST COMPLETE" SEVERITY NOTE;
        REPORT "========================================" SEVERITY NOTE;
        
        WAIT;
    END PROCESS;

END ARCHITECTURE test;
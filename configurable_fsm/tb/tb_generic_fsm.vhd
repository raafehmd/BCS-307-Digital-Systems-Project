LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_generic_fsm IS
END ENTITY tb_generic_fsm;

ARCHITECTURE behavior OF tb_generic_fsm IS

    COMPONENT generic_fsm
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

    COMPONENT config_rom
        PORT (
            clk      : IN  STD_LOGIC;
            addr     : IN  STD_LOGIC_VECTOR(16 DOWNTO 0);
            data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    -- Signals
    SIGNAL clk             : STD_LOGIC := '0';
    SIGNAL reset           : STD_LOGIC := '1';
    SIGNAL event_code      : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL config_data     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL config_id       : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; -- Traffic Light
    SIGNAL interrupt_event : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL state_code      : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL output_action   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL config_addr     : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL output_valid    : STD_LOGIC;
    SIGNAL fsm_busy        : STD_LOGIC;
    SIGNAL timer_start_out : STD_LOGIC;
    SIGNAL timer_reset_out : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    -- Instantiate DUT
    UUT: generic_fsm
        PORT MAP (
            clk             => clk,
            reset           => reset,
            event_code      => event_code,
            config_data     => config_data,
            config_id       => config_id,
            interrupt_event => interrupt_event,
            state_code      => state_code,
            output_action   => output_action,
            config_addr     => config_addr,
            output_valid    => output_valid,
            fsm_busy        => fsm_busy,
            timer_start_out => timer_start_out,
            timer_reset_out => timer_reset_out
        );

    -- Instantiate ROM
    ROM_INST: config_rom
        PORT MAP (
            clk      => clk,
            addr     => config_addr,
            data_out => config_data
        );

    -- Clock Generation
    clk <= NOT clk AFTER CLK_PERIOD / 2;

    -- Stimulus Process
    STIM_PROC: PROCESS
    BEGIN
        -- 1. Initial Reset
        WAIT FOR 20 ns; -- Hold reset for 2 cycles
        reset <= '0';
        WAIT FOR 10 ns; -- Wait for rising edge after reset deassertion

        -- Check Reset State
        ASSERT state_code = "00000" REPORT "FAIL: Reset did not set state to IDLE" SEVERITY ERROR;
        ASSERT output_valid = '0' REPORT "FAIL: Output valid should be 0 after reset" SEVERITY ERROR;

        -- ---------------------------------------------------------
        -- TEST 1: Normal Transition (IDLE -> RED via Car Sensor)
        -- 5-CYCLE PIPELINE LATENCY (with trigger delay to avoid race condition)
        --   Cycle 1: Event captured
        --   Cycle 2: ROM data available  
        --   Cycle 3: Data moved to p3, trigger generated
        --   Cycle 4: Trigger propagates to next cycle
        --   Cycle 5: State update executes with delayed trigger
        -- ---------------------------------------------------------
        REPORT "TEST 1: Normal Transition (IDLE -> RED)";
        
        -- T=30ns: Present Event
        event_code <= "0000000010"; -- Event 2
        WAIT FOR 10 ns; -- T=40ns (Rising Edge 1: Cycle 1)
        
        WAIT FOR 10 ns; -- T=50ns (Rising Edge 2: Cycle 2)
        WAIT FOR 10 ns; -- T=60ns (Rising Edge 3: Cycle 3)
        WAIT FOR 10 ns; -- T=70ns (Rising Edge 4: Cycle 4)
        WAIT FOR 10 ns; -- T=80ns (Rising Edge 5: Cycle 5 - State update happens)
        
        REPORT "Cycle 5 @ T=80ns: state_code=" & integer'image(to_integer(unsigned(state_code))) & 
                ", output_valid=" & std_logic'image(output_valid) &
                ", output_action=" & integer'image(to_integer(unsigned(output_action)));
        
        -- Check State and Outputs
        ASSERT state_code = "00001" REPORT "FAIL: State did not transition to RED (00001)" SEVERITY ERROR;
        ASSERT output_valid = '1' REPORT "FAIL: Output valid should be 1 after state update" SEVERITY ERROR;
        ASSERT output_action = X"0001" REPORT "FAIL: Output action incorrect for RED state" SEVERITY ERROR;
        ASSERT timer_start_out = '1' REPORT "FAIL: Timer Start pulse missing" SEVERITY ERROR;
        ASSERT timer_reset_out = '1' REPORT "FAIL: Timer Reset pulse missing" SEVERITY ERROR;

        REPORT "PASS: TEST 1 completed successfully";

        -- Clear Event
        event_code <= (OTHERS => '0');
        WAIT FOR 10 ns; 

        -- ---------------------------------------------------------
        -- TEST 2: Second Transition (RED -> GREEN via Timer)
        -- ---------------------------------------------------------
        REPORT "TEST 2: Second Transition (RED -> GREEN)";
        
        -- We're currently in RED state. Present Timer event (Event 4)
        event_code <= "0000000100"; -- Event 4 (Timer)
        WAIT FOR 50 ns; -- Wait 5 cycles for state update
        
        ASSERT state_code = "00010" REPORT "FAIL: State did not transition to GREEN (00010)" SEVERITY ERROR;
        ASSERT output_valid = '1' REPORT "FAIL: Output valid should be 1 on state transition" SEVERITY ERROR;

        REPORT "PASS: TEST 2 completed successfully";

        -- Clear Event
        event_code <= (OTHERS => '0');
        WAIT FOR 10 ns;

        -- ---------------------------------------------------------
        -- TEST 3: Interrupt Verification
        -- ---------------------------------------------------------
        REPORT "TEST 3: Interrupt Logic";
        
        -- Set Interrupt Event Code to 9
        interrupt_event <= "0000001001"; 
        
        -- We're in GREEN state. Present Interrupt Event 9
        event_code <= "0000001001"; 
        WAIT FOR 50 ns; -- Wait 5 cycles for state update
        
        ASSERT state_code = "00000" REPORT "FAIL: Interrupt did not force IDLE state" SEVERITY ERROR;
        ASSERT output_valid = '1' REPORT "FAIL: Output valid should be high on interrupt cycle" SEVERITY ERROR;

        REPORT "PASS: TEST 3 completed successfully";
        
        -- Cleanup
        interrupt_event <= (OTHERS => '0');
        event_code <= (OTHERS => '0');
        WAIT FOR 20 ns;

        REPORT "SIMULATION FINISHED: All Tests Passed";
        WAIT;
    END PROCESS;

END ARCHITECTURE;
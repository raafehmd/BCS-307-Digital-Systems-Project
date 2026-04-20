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

    SIGNAL clk             : STD_LOGIC := '0';
    SIGNAL reset           : STD_LOGIC := '1';
    SIGNAL event_code      : STD_LOGIC_VECTOR(9 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL config_data     : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL config_id       : STD_LOGIC_VECTOR(1 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL interrupt_event : STD_LOGIC_VECTOR(9 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL state_code      : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL output_action   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL config_addr     : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL output_valid    : STD_LOGIC;
    SIGNAL fsm_busy        : STD_LOGIC;
    SIGNAL timer_start_out : STD_LOGIC;
    SIGNAL timer_reset_out : STD_LOGIC;
    SIGNAL rom_data        : STD_LOGIC_VECTOR(31 DOWNTO 0);

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    fsm_inst : generic_fsm PORT MAP (
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

    rom_inst : config_rom PORT MAP (
        clk      => clk,
        addr     => config_addr,
        data_out => rom_data
    );

    config_data <= rom_data;

    clk <= NOT clk AFTER CLK_PERIOD / 2;

    stim : PROCESS

        VARIABLE n_pass : INTEGER := 0;
        VARIABLE n_fail : INTEGER := 0;

        PROCEDURE check(cond : IN BOOLEAN; pmsg : IN STRING; fmsg : IN STRING) IS
        BEGIN
            IF cond THEN
                REPORT "PASS: " & pmsg;
                n_pass := n_pass + 1;
            ELSE
                REPORT "FAIL: " & fmsg SEVERITY ERROR;
                n_fail := n_fail + 1;
            END IF;
        END PROCEDURE;

    BEGIN

        REPORT "========================================";
        REPORT "STARTING FSM TESTBENCH";
        REPORT "========================================";

        -- ================================================================
        -- TEST 1: Reset forces IDLE state
        -- ================================================================
        REPORT "--- TEST 1: Reset ---";
        reset     <= '1';
        config_id <= "00";
        WAIT FOR 20 ns;

        check(state_code = "00000",
              "Reset forced state to IDLE (00000)",
              "Reset did not set IDLE state");

        reset <= '0';
        WAIT FOR 10 ns;

        -- ================================================================
        -- TEST 2: Event Capture asserts fsm_busy
        -- ================================================================
        REPORT "--- TEST 2: Event Capture ---";
        event_code <= "0000000001";
        WAIT FOR 10 ns;

        check(fsm_busy = '1',
              "FSM busy asserted on event",
              "FSM busy did not assert");

        WAIT FOR 10 ns;

        -- ================================================================
        -- TEST 3: ROM Address Computation
        -- ================================================================
        REPORT "--- TEST 3: ROM Address Computation ---";

        check(config_addr = ("00" & "00000" & "0000000001"),
              "ROM address correct (config_id & state & event)",
              "ROM address incorrect");

        event_code <= (OTHERS => '0');
        WAIT FOR 30 ns;

        -- ================================================================
        -- TEST 4: ROM Data Reception
        -- ================================================================
        REPORT "--- TEST 4: ROM Data Reception ---";

        check(rom_data /= (rom_data'RANGE => '0'),
              "ROM data received: "
                  & INTEGER'IMAGE(to_integer(unsigned(rom_data(28 DOWNTO 24)))),
              "ROM data all zeros");

        WAIT FOR 20 ns;

        -- ================================================================
        -- TEST 5: State Update Check
        -- ================================================================
        REPORT "--- TEST 5: State Update Check ---";

        check(state_code = "00001"
              AND output_action = x"0001"
              AND output_valid    = '0'
              AND timer_start_out = '0'
              AND timer_reset_out = '0',
              "State advanced to 1, output_action=1, valid/timer signals low",
              "State/output/timer signals not at expected values "
              & "(state=" & INTEGER'IMAGE(to_integer(unsigned(state_code)))
              & " action=" & INTEGER'IMAGE(to_integer(unsigned(output_action)))
              & " valid=" & STD_LOGIC'IMAGE(output_valid)
              & " tstart=" & STD_LOGIC'IMAGE(timer_start_out)
              & " trst=" & STD_LOGIC'IMAGE(timer_reset_out) & ")");

        WAIT FOR 50 ns;

        -- ================================================================
        REPORT "========================================";
        REPORT "RESULTS: " & integer'image(n_pass) & " PASSED, "
               & integer'image(n_fail) & " FAILED";
        REPORT "========================================";
        std.env.finish;

    END PROCESS stim;

END ARCHITECTURE test;
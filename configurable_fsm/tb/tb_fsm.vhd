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
            timer_reset_out : OUT STD_LOGIC;
            fsm_error       : OUT STD_LOGIC
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
    SIGNAL fsm_error       : STD_LOGIC;
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
        timer_reset_out => timer_reset_out,
        fsm_error       => fsm_error);

    rom_inst : config_rom PORT MAP (
        clk      => clk,
        addr     => config_addr,
        data_out => rom_data);

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
        REPORT "STARTING FSM TESTBENCH (IMPROVED)";
        REPORT "========================================";

        -- TEST 1: Reset forces IDLE
        REPORT "--- TEST 1: Reset ---";
        reset <= '1'; config_id <= "00";
        WAIT FOR 20 ns;
        check(state_code = "00000", "Reset forced IDLE", "Reset did not set IDLE");
        reset <= '0';
        WAIT FOR 10 ns;

        -- TEST 2: Event capture asserts fsm_busy
        REPORT "--- TEST 2: Event Capture ---";
        event_code <= "0000000001";
        WAIT FOR 10 ns;
        check(fsm_busy = '1', "FSM busy on event", "FSM busy did not assert");
        WAIT FOR 10 ns;

        -- TEST 3: ROM address = config_id & state & event
        REPORT "--- TEST 3: ROM Address ---";
        check(config_addr = ("00" & "00000" & "0000000001"),
              "ROM address correct", "ROM address incorrect");
        event_code <= (OTHERS => '0');
        WAIT FOR 30 ns;

        -- TEST 4: ROM returns non-zero data for a mapped entry
        REPORT "--- TEST 4: ROM Data ---";
        check(rom_data /= (rom_data'RANGE => '0'),
              "ROM data non-zero", "ROM data all zeros");
        WAIT FOR 20 ns;

        -- TEST 5: State advances and output_action is set correctly
        REPORT "--- TEST 5: State Update ---";
        check(state_code = "00001" AND output_action = x"0001",
              "State advanced, output correct", "State/output mismatch");
        WAIT FOR 50 ns;

        -- ----------------------------------------------------------------
        -- TEST 6: Interrupt mechanism
        -- FIX: switch to vending config (id="01") where interrupt_en='1'
        -- entries exist. The cancel event (32="0000100000") from COLLECT
        -- state has interrupt_en='1' at ROM addr 2080, so when
        -- event_code = interrupt_event the FSM correctly returns to IDLE.
        -- Previous test used traffic-light config (id="00") which has NO
        -- interrupt_en='1' entries, so the interrupt path never fired.
        -- ----------------------------------------------------------------
        REPORT "--- TEST 6: Interrupt Mechanism ---";
        reset           <= '1';
        WAIT FOR 20 ns;
        reset           <= '0';
        config_id       <= "01";           -- vending machine ROM
        interrupt_event <= "0000100000";   -- cancel_btn = VM_INTERRUPT_EVENT (bit 5)
        WAIT FOR 10 ns;

        -- Advance FSM to COLLECT via coin event
        event_code <= "0000000001";        -- coin_insert = bit 0
        WAIT FOR CLK_PERIOD * 5;
        event_code <= (OTHERS => '0');
        WAIT FOR CLK_PERIOD * 3;
        check(state_code = "00010",
              "Reached COLLECT state ready for interrupt test",
              "Did not reach COLLECT - interrupt test precondition failed");

        -- Fire cancel (= interrupt_event) from COLLECT
        event_code <= "0000100000";        -- cancel = VM_INTERRUPT_EVENT
        WAIT FOR 10 ns;
        check(fsm_busy = '1', "Busy on interrupt event", "Busy not asserted");
        event_code <= (OTHERS => '0');
        WAIT FOR CLK_PERIOD * 5;
        check(state_code = "00000",
              "Interrupt returned FSM to IDLE",
              "FSM did not return to IDLE after interrupt");
        interrupt_event <= (OTHERS => '0');
        WAIT FOR 20 ns;

        -- ----------------------------------------------------------------
        -- TEST 7: ROM miss → fsm_error
        -- FIX: wait 5 clock cycles (was 4) after the unmapped event so the
        -- 3-stage pipeline fully propagates before checking fsm_error.
        -- Event 7 is not in the serial ROM (config_id="11"), so
        -- config_data returns all-zeros and fsm_error pulses for 1 cycle.
        -- ----------------------------------------------------------------
        REPORT "--- TEST 7: ROM Miss -> fsm_error ---";
        reset <= '1';
        WAIT FOR 20 ns;
        reset     <= '0';
        config_id <= "11";                 -- serial config
        WAIT FOR 10 ns;
        event_code <= "0000000111";        -- unmapped entry in serial ROM
        WAIT FOR CLK_PERIOD * 5;           -- FIX: pipeline needs 3+ cycles
        check(fsm_error = '1', "fsm_error fired on ROM miss", "fsm_error did not fire");
        event_code <= (OTHERS => '0');
        WAIT FOR 20 ns;

        REPORT "========================================";
        REPORT "RESULTS: " & INTEGER'IMAGE(n_pass) & " PASSED, "
               & INTEGER'IMAGE(n_fail) & " FAILED";
        REPORT "========================================";
        STD.ENV.FINISH;

    END PROCESS stim;

END ARCHITECTURE test;
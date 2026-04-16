LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_serial IS
END ENTITY tb_serial;

ARCHITECTURE sim OF tb_serial IS

    SIGNAL clk        : STD_LOGIC := '0';
    SIGNAL reset      : STD_LOGIC := '0';
    SIGNAL rx_data    : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rx_valid   : STD_LOGIC := '0';
    SIGNAL tx_ready   : STD_LOGIC := '0';
    SIGNAL tx_data    : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL tx_enable  : STD_LOGIC;
    SIGNAL parity_err : STD_LOGIC;
    SIGNAL state_out  : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL fsm_busy   : STD_LOGIC;

    CONSTANT SP_IDLE     : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";
    CONSTANT SP_RX_BIT1  : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00011";
    CONSTANT SP_RX_BIT3  : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00101";
    CONSTANT SP_COMPLETE : STD_LOGIC_VECTOR(4 DOWNTO 0) := "01011";

    CONSTANT CLK_PERIOD : TIME := 10 ns;

BEGIN

    dut: ENTITY work.serial_wrapper
        PORT MAP (
            clk => clk, reset => reset,
            rx_data => rx_data, rx_valid => rx_valid, tx_ready => tx_ready,
            tx_data => tx_data, tx_enable => tx_enable,
            parity_err => parity_err, state_out => state_out
        );

    fsm_busy <= <<SIGNAL .tb_serial.dut.fsm_busy : STD_LOGIC>>;
    clk <= NOT clk AFTER CLK_PERIOD / 2;

    stim: PROCESS

        VARIABLE n_pass    : INTEGER := 0;
        VARIABLE n_fail    : INTEGER := 0;
        VARIABLE perr_seen : BOOLEAN := FALSE;
        VARIABLE st_before : STD_LOGIC_VECTOR(4 DOWNTO 0);
        VARIABLE cnt       : INTEGER;

        -- Assert rx_valid until state_code changes, then deassert and settle.
        PROCEDURE do_rx (data : IN STD_LOGIC_VECTOR(7 DOWNTO 0)) IS
            VARIABLE st0 : STD_LOGIC_VECTOR(4 DOWNTO 0);
        BEGIN
            st0 := state_out;
            rx_data  <= data;
            rx_valid <= '1';
            LOOP
                WAIT UNTIL rising_edge(clk);
                EXIT WHEN state_out /= st0;
            END LOOP;
            rx_valid <= '0';
            rx_data  <= (OTHERS => '0');
            WAIT UNTIL rising_edge(clk) AND fsm_busy = '0';
            WAIT UNTIL rising_edge(clk);
        END PROCEDURE;

        -- Send a complete UART frame for one byte (LSB first).
        --
        -- Pulse layout:
        --   1 start pulse  : send full byte (even parity required)
        --   1 sync pulse   : START->BIT0, latch gated off (state=START)
        --   8 data pulses  : bit0..bit7, rx_data(0)=bit value
        --                    rx_data(1) set to fix parity when bit=1
        --   1 stop pulse   : send full byte again (even parity required)
        --
        -- At SP_COMPLETE: tx_data must equal the original byte.
        PROCEDURE send_byte (byte : IN STD_LOGIC_VECTOR(7 DOWNTO 0)) IS
            VARIABLE bit_data : STD_LOGIC_VECTOR(7 DOWNTO 0);
        BEGIN
            do_rx(byte);    -- pulse 1: IDLE -> START
            do_rx(byte);    -- pulse 2: START -> RX_BIT0 (latch gated off)
            -- pulses 3-10: individual data bits, LSB first
            FOR i IN 0 TO 7 LOOP
                bit_data    := (OTHERS => '0');
                bit_data(0) := byte(i);
                -- If bit=1, rx_data = 0x03 (bits 0 and 1 set = even parity)
                -- If bit=0, rx_data = 0x00 (no bits set = even parity)
                IF byte(i) = '1' THEN
                    bit_data(1) := '1';
                END IF;
                do_rx(bit_data);
            END LOOP;
            do_rx(byte);    -- pulse 11: STOP -> COMPLETE (latch gated off)
        END PROCEDURE;

        PROCEDURE do_txr IS
            VARIABLE st0 : STD_LOGIC_VECTOR(4 DOWNTO 0);
        BEGIN
            st0 := state_out;
            tx_ready <= '1';
            LOOP
                WAIT UNTIL rising_edge(clk);
                EXIT WHEN state_out /= st0;
            END LOOP;
            tx_ready <= '0';
            WAIT UNTIL rising_edge(clk) AND fsm_busy = '0';
            WAIT UNTIL rising_edge(clk);
        END PROCEDURE;

        PROCEDURE check (cond : IN BOOLEAN; pmsg : IN STRING; fmsg : IN STRING) IS
        BEGIN
            IF cond THEN
                REPORT "PASS: " & pmsg; n_pass := n_pass + 1;
            ELSE
                REPORT "FAIL: " & fmsg SEVERITY ERROR; n_fail := n_fail + 1;
            END IF;
        END PROCEDURE;

    BEGIN

        reset <= '1'; WAIT FOR CLK_PERIOD * 4;
        WAIT UNTIL rising_edge(clk); reset <= '0'; WAIT FOR CLK_PERIOD * 2;

        check(state_out = SP_IDLE, "SP_IDLE after reset",
              "Expected SP_IDLE, got " & to_string(state_out));

        -- ================================================================
        -- TEST 1-3: Receive 0xA5, verify tx_data = 0xA5
        -- 0xA5 = 1010_0101 (even parity)
        -- ================================================================
        REPORT "--- TEST 1-3: Receive 0xA5, verify tx_data ---";

        send_byte(x"A5");

        check(state_out = SP_COMPLETE,
              "SP_COMPLETE after receiving 0xA5",
              "Expected SP_COMPLETE, got " & to_string(state_out));
        check(tx_enable = '1',
              "tx_enable=1 at SP_COMPLETE",
              "Expected tx_enable=1, got " & to_string(tx_enable));
        check(tx_data = x"A5",
              "tx_data=0xA5 (correct byte received)",
              "Expected tx_data=0xA5, got 0x" & to_hstring(tx_data));

        -- ================================================================
        -- TEST 4-8: tx_ready then receive 0x3C, verify tx_data = 0x3C
        -- 0x3C = 0011_1100 (even parity)
        -- Confirms latch cleared correctly between frames.
        -- ================================================================
        REPORT "--- TEST 4-8: Receive 0x3C, verify tx_data ---";

        do_txr;
        check(state_out = SP_IDLE, "SP_IDLE after tx_ready",
              "Expected SP_IDLE, got " & to_string(state_out));

        send_byte(x"3C");

        check(state_out = SP_COMPLETE,
              "SP_COMPLETE after receiving 0x3C",
              "Expected SP_COMPLETE, got " & to_string(state_out));
        check(tx_data = x"3C",
              "tx_data=0x3C (correct byte received)",
              "Expected tx_data=0x3C, got 0x" & to_hstring(tx_data));

        do_txr;
        check(tx_enable = '0', "tx_enable=0 after tx_ready",
              "Expected tx_enable=0, got " & to_string(tx_enable));

        -- ================================================================
        -- TEST 3: Parity error mid-reception -> SP_IDLE + parity_err
        -- ================================================================
        REPORT "--- TEST 9-11: Parity error interrupt ---";

        do_rx(x"A5");   -- IDLE->START
        do_rx(x"A5");   -- START->BIT0  (sync pulse, latch off)
        do_rx(x"03");   -- BIT0->BIT1   (bit0=1, parity OK via 0x03)

        check(state_out = SP_RX_BIT1,
              "At SP_RX_BIT1 before parity error",
              "Expected BIT1(00011), got " & to_string(state_out));

        -- 0x01 has bit0=1, bits[7:1]=0 -> odd parity -> interrupt fires
        perr_seen := FALSE;
        st_before := state_out;
        cnt := 0;
        rx_data  <= x"01";
        rx_valid <= '1';
        LOOP
            WAIT UNTIL rising_edge(clk);
            cnt := cnt + 1;
            IF parity_err = '1' THEN perr_seen := TRUE; END IF;
            EXIT WHEN state_out /= st_before OR cnt >= 20;
        END LOOP;
        rx_valid <= '0'; rx_data <= (OTHERS => '0');
        WAIT UNTIL rising_edge(clk);
        IF parity_err = '1' THEN perr_seen := TRUE; END IF;
        WAIT UNTIL rising_edge(clk);

        check(state_out = SP_IDLE,
              "SP_IDLE after parity error",
              "Expected SP_IDLE, got " & to_string(state_out));
        check(perr_seen,
              "parity_err pulsed after interrupt",
              "parity_err never went high");

        -- ================================================================
        -- TEST 4: Reset during active reception
        -- ================================================================
        REPORT "--- TEST 12-14: Reset during reception ---";

        do_rx(x"A5");   -- IDLE->START
        do_rx(x"A5");   -- START->BIT0
        do_rx(x"03");   -- BIT0->BIT1 (bit0=1)
        do_rx(x"00");   -- BIT1->BIT2 (bit1=0)
        do_rx(x"03");   -- BIT2->BIT3 (bit2=1)

        check(state_out = SP_RX_BIT3,
              "At SP_RX_BIT3 before reset",
              "Expected BIT3(00101), got " & to_string(state_out));

        reset <= '1'; WAIT FOR CLK_PERIOD * 3;
        WAIT UNTIL rising_edge(clk); reset <= '0'; WAIT FOR CLK_PERIOD * 3;

        check(state_out = SP_IDLE,
              "SP_IDLE after mid-reception reset",
              "Expected SP_IDLE, got " & to_string(state_out));
        check(tx_enable = '0',
              "tx_enable=0 after reset",
              "Expected tx_enable=0 after reset");

        -- ================================================================
        WAIT FOR CLK_PERIOD * 5;
        REPORT "========================================";
        REPORT "RESULTS: " & integer'image(n_pass) & " PASSED, "
               & integer'image(n_fail) & " FAILED";
        REPORT "========================================";
        std.env.finish;

    END PROCESS stim;

END ARCHITECTURE sim;
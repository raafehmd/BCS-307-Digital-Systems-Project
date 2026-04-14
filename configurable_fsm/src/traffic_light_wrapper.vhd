-- ============================================================================
-- TRAFFIC LIGHT WRAPPER
-- Application wrapper for configurable FSM core
--
-- Reference: Configurable FSM Master Doc, Section 5.1, 7.4.1
-- ============================================================================

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY traffic_light_wrapper IS
    PORT (
        clk         : IN  STD_LOGIC;
        reset       : IN  STD_LOGIC;
        pedestrian_btn  : IN  STD_LOGIC;
        car_sensor      : IN  STD_LOGIC;
        timer_done      : IN  STD_LOGIC;
        red_led     : OUT STD_LOGIC;
        yellow_led  : OUT STD_LOGIC;
        green_led   : OUT STD_LOGIC;
        ped_signal  : OUT STD_LOGIC;
        timer_start : OUT STD_LOGIC;
        timer_reset : OUT STD_LOGIC
    );
END ENTITY traffic_light_wrapper;

ARCHITECTURE structural OF traffic_light_wrapper IS
    CONSTANT TL_CONFIG_ID : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    CONSTANT EV_PEDESTRIAN_BTN : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000001";
    CONSTANT EV_CAR_SENSOR     : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000010";
    CONSTANT EV_TIMER_DONE     : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0000000100";

    SIGNAL event_code      : STD_LOGIC_VECTOR(9 DOWNTO 0);
    SIGNAL config_data     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL config_addr     : STD_LOGIC_VECTOR(16 DOWNTO 0);
    SIGNAL output_action   : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL state_code      : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL output_valid    : STD_LOGIC;
    SIGNAL fsm_busy        : STD_LOGIC;
    SIGNAL timer_start_sig : STD_LOGIC;
    SIGNAL timer_reset_sig : STD_LOGIC;
    SIGNAL reset_timer_clear : STD_LOGIC := '0';
    SIGNAL timer_reset_combined : STD_LOGIC;
BEGIN
    -- Input decoder: priority pedestrian > car > timer
    input_decoder: PROCESS(pedestrian_btn, car_sensor, timer_done, fsm_busy)
    BEGIN
        event_code <= (OTHERS => '0');
        IF fsm_busy = '0' THEN
            IF pedestrian_btn = '1' THEN
                event_code <= EV_PEDESTRIAN_BTN;
            ELSIF car_sensor = '1' THEN
                event_code <= EV_CAR_SENSOR;
            ELSIF timer_done = '1' THEN
                event_code <= EV_TIMER_DONE;
            END IF;
        END IF;
    END PROCESS input_decoder;

    -- Configuration ROM
    rom_inst: ENTITY work.config_rom
        PORT MAP (clk => clk, addr => config_addr, data_out => config_data);

    -- Generic FSM core
    fsm_core: ENTITY work.generic_fsm
        PORT MAP (
            clk => clk, reset => reset, event_code => event_code,
            config_data => config_data, config_id => TL_CONFIG_ID,
            interrupt_event => (OTHERS => '0'),
            state_code => state_code, output_action => output_action,
            config_addr => config_addr, output_valid => output_valid,
            fsm_busy => fsm_busy, timer_start_out => timer_start_sig,
            timer_reset_out => timer_reset_sig);

    -- Timer initialization on reset
    timer_init: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                reset_timer_clear <= '1';
            ELSIF reset_timer_clear = '1' THEN
                reset_timer_clear <= '0';
            END IF;
        END IF;
    END PROCESS timer_init;

    timer_reset_combined <= timer_reset_sig OR reset_timer_clear;

    -- Output encoder
    red_led    <= output_action(0);
    yellow_led <= output_action(1);
    green_led  <= output_action(2);
    ped_signal <= output_action(3);

    timer_start <= timer_start_sig;
    timer_reset <= timer_reset_combined;
END ARCHITECTURE structural;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_top is
    Port ( 
        clk : in STD_LOGIC;                         -- 100 MHz system clock
        btnC : in STD_LOGIC;                        -- Center button (for future use)
        btnU : in STD_LOGIC;                        -- Up button
        btnD : in STD_LOGIC;                        -- Down button
        btnL : in STD_LOGIC;                        -- Left button
        btnR : in STD_LOGIC;                        -- Right button
        vgaRed : out STD_LOGIC_VECTOR(3 downto 0);  -- Red VGA output
        vgaGreen : out STD_LOGIC_VECTOR(3 downto 0);-- Green VGA output
        vgaBlue : out STD_LOGIC_VECTOR(3 downto 0); -- Blue VGA output
        Hsync : out STD_LOGIC;                      -- Horizontal sync
        Vsync : out STD_LOGIC;                      -- Vertical sync
        seg : out STD_LOGIC_VECTOR(6 downto 0);     -- 7-segment display segments
        an : out STD_LOGIC_VECTOR(3 downto 0)       -- 7-segment display anodes
    );
end snake_top;

architecture Behavioral of snake_top is
    -- Component declarations
    component clock_divider is
        Port ( 
            clk_in : in STD_LOGIC;
            reset : in STD_LOGIC;
            clk_vga : out STD_LOGIC;
            clk_25Hz : out STD_LOGIC
        );
    end component;
    
    component vga_controller is
        Port ( 
            clk_25MHz : in STD_LOGIC;
            reset : in STD_LOGIC;
            h_sync : out STD_LOGIC;
            v_sync : out STD_LOGIC;
            display_enable : out STD_LOGIC;
            column : out INTEGER range 0 to 639;
            row : out INTEGER range 0 to 479
        );
    end component;
    
    component lfsr is
        Port ( 
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            enable : in STD_LOGIC;
            random_num : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;
    
    component game_logic is
        Port ( 
            clk_25Hz : in STD_LOGIC;
            reset : in STD_LOGIC;
            btn_up : in STD_LOGIC;
            btn_down : in STD_LOGIC;
            btn_left : in STD_LOGIC;
            btn_right : in STD_LOGIC;
            short_press : in STD_LOGIC;
            long_press : in STD_LOGIC;
            random_num : in STD_LOGIC_VECTOR(7 downto 0);
            pixel_x : in INTEGER range 0 to 639;
            pixel_y : in INTEGER range 0 to 479;
            rgb_out : out STD_LOGIC_VECTOR(11 downto 0);
            score : out INTEGER range 0 to 999
        );
    end component;
    
    component segment_display is
        Port ( 
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            score : in INTEGER range 0 to 999;
            seg : out STD_LOGIC_VECTOR(6 downto 0);
            an : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;
    
    -- Internal signals
    signal clk_vga : STD_LOGIC;
    signal clk_25Hz : STD_LOGIC;
    signal reset : STD_LOGIC;
    signal display_enable : STD_LOGIC;
    signal column : INTEGER range 0 to 639;
    signal row : INTEGER range 0 to 479;
    signal random_num : STD_LOGIC_VECTOR(7 downto 0);
    signal rgb : STD_LOGIC_VECTOR(11 downto 0);
    signal score : INTEGER range 0 to 999;
    
    -- btnC control signals
    signal short_press, long_press : STD_LOGIC;
    signal btnC_sync : std_logic_vector(2 downto 0) := "000";
    signal btnC_debounced : std_logic := '0';
    signal btnC_prev : std_logic := '0';
    signal btnC_pressed : std_logic := '0';
    signal btnC_released : std_logic := '0';
    signal btnC_press_counter : unsigned(26 downto 0) := (others => '0');
    signal btnC_press_active : std_logic := '0';
    
    -- Timing constants for btnC (at 50MHz)
    constant SHORT_PRESS_TIME : integer := 5000000;   -- 100ms minimum press
    constant LONG_PRESS_TIME : integer := 100000000;  -- 2 seconds for restart
    
    -- Debounced button signals
    signal btn_up_db, btn_down_db, btn_left_db, btn_right_db : STD_LOGIC;
    
    -- Simple debounce counter
    signal debounce_counter : unsigned(19 downto 0) := (others => '0');
    
begin
    -- Global reset (can be tied to a switch if needed, or keep as '0')
    reset <= '0';
    
    -- Clock divider instantiation
    ClockDiv: clock_divider
    port map (
        clk_in => clk,
        reset => reset,
        clk_vga => clk_vga,
        clk_25Hz => clk_25Hz
    );
    
    -- VGA controller instantiation
    VGA: vga_controller
    port map (
        clk_25MHz => clk_vga,  -- Using the 50MHz clock for VGA
        reset => reset,
        h_sync => Hsync,
        v_sync => Vsync,
        display_enable => display_enable,
        column => column,
        row => row
    );
    
    -- LFSR for random number generation
    RNG: lfsr
    port map (
        clk => clk_vga,
        reset => reset,
        enable => clk_25Hz,
        random_num => random_num
    );
    
    -- Simple button debounce
    process(clk_vga, reset)
    begin
        if reset = '1' then
            debounce_counter <= (others => '0');
            btn_up_db <= '0';
            btn_down_db <= '0';
            btn_left_db <= '0';
            btn_right_db <= '0';
        elsif rising_edge(clk_vga) then
            debounce_counter <= debounce_counter + 1;
            
            if debounce_counter = 0 then
                btn_up_db <= btnU;
                btn_down_db <= btnD;
                btn_left_db <= btnL;
                btn_right_db <= btnR;
            end if;
        end if;
    end process;
    
    -- btnC synchronizer and debounce
    process(clk_vga, reset)
    begin
        if reset = '1' then
            btnC_sync <= "000";
        elsif rising_edge(clk_vga) then
            btnC_sync <= btnC_sync(1 downto 0) & btnC;
        end if;
    end process;
    
    btnC_debounced <= btnC_sync(2);
    
    -- btnC edge detection
    process(clk_vga, reset)
    begin
        if reset = '1' then
            btnC_prev <= '0';
            btnC_pressed <= '0';
            btnC_released <= '0';
        elsif rising_edge(clk_vga) then
            btnC_pressed <= '0';
            btnC_released <= '0';
            
            if btnC_debounced = '1' and btnC_prev = '0' then
                btnC_pressed <= '1';
            elsif btnC_debounced = '0' and btnC_prev = '1' then
                btnC_released <= '1';
            end if;
            
            btnC_prev <= btnC_debounced;
        end if;
    end process;
    
    -- btnC press duration counter and detection
    process(clk_vga, reset)
    begin
        if reset = '1' then
            btnC_press_counter <= (others => '0');
            btnC_press_active <= '0';
            short_press <= '0';
            long_press <= '0';
        elsif rising_edge(clk_vga) then
            -- Toggle generation instead of pulse
            if btnC_pressed = '1' then
                -- Button just pressed, start counting
                btnC_press_counter <= (others => '0');
                btnC_press_active <= '1';
            elsif btnC_released = '1' and btnC_press_active = '1' then
                -- Button released, check duration
                if btnC_press_counter >= SHORT_PRESS_TIME and btnC_press_counter < LONG_PRESS_TIME then
                    short_press <= not short_press;  -- Toggle on short press event
                end if;
                btnC_press_active <= '0';
            elsif btnC_press_active = '1' then
                -- Button still pressed, count duration
                if btnC_press_counter < LONG_PRESS_TIME then
                    btnC_press_counter <= btnC_press_counter + 1;
                elsif btnC_press_counter >= LONG_PRESS_TIME then
                    long_press <= not long_press;  -- Long press detected (restart)
                    btnC_press_active <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Game logic instantiation
    Game: game_logic
    port map (
        clk_25Hz => clk_25Hz,
        reset => reset,
        btn_up => btn_up_db,
        btn_down => btn_down_db,
        btn_left => btn_left_db,
        btn_right => btn_right_db,
        short_press => short_press,
        long_press => long_press,
        random_num => random_num,
        pixel_x => column,
        pixel_y => row,
        rgb_out => rgb,
        score => score
    );
    
    -- 7-segment display controller instantiation
    Display: segment_display
    port map (
        clk => clk_vga,
        reset => reset,
        score => score,
        seg => seg,
        an => an
    );
    
    -- RGB output assignment
    process(display_enable, rgb)
    begin
        if display_enable = '1' then
            vgaRed <= rgb(11 downto 8);
            vgaGreen <= rgb(7 downto 4);
            vgaBlue <= rgb(3 downto 0);
        else
            vgaRed <= (others => '0');
            vgaGreen <= (others => '0');
            vgaBlue <= (others => '0');
        end if;
    end process;
    
end Behavioral;
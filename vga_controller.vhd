library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port ( 
        clk_25MHz : in STD_LOGIC;  -- Now actually 50MHz
        reset : in STD_LOGIC;
        h_sync : out STD_LOGIC;
        v_sync : out STD_LOGIC;
        display_enable : out STD_LOGIC;
        column : out INTEGER range 0 to 639;
        row : out INTEGER range 0 to 479
    );
end vga_controller;

architecture Behavioral of vga_controller is
    -- VGA 640x480 @ 60Hz timing parameters for 50MHz pixel clock
    -- Scaling timing parameters for 50MHz
    constant H_DISPLAY : INTEGER := 640;
    constant H_FRONT_PORCH : INTEGER := 16;
    constant H_SYNC_PULSE : INTEGER := 96;
    constant H_BACK_PORCH : INTEGER := 48;
    constant H_TOTAL : INTEGER := H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; -- 800
    
    -- Vertical timing (in lines)
    constant V_DISPLAY : INTEGER := 480;
    constant V_FRONT_PORCH : INTEGER := 10;
    constant V_SYNC_PULSE : INTEGER := 2;
    constant V_BACK_PORCH : INTEGER := 29;
    constant V_TOTAL : INTEGER := V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; -- 521
    
    -- Internal counters
    signal h_count : INTEGER range 0 to H_TOTAL - 1 := 0;
    signal v_count : INTEGER range 0 to V_TOTAL - 1 := 0;
    
    -- Active display area signals
    signal h_display_active : STD_LOGIC := '0';
    signal v_display_active : STD_LOGIC := '0';
    
begin
    -- Use direct 50MHz input for better compatibility with modern monitors
    -- Horizontal counter process
    process(clk_25MHz, reset)
    begin
        if reset = '1' then
            h_count <= 0;
        elsif rising_edge(clk_25MHz) then  -- Using 50MHz directly
            if h_count = H_TOTAL - 1 then
                h_count <= 0;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;
    
    -- Vertical counter process
    process(clk_25MHz, reset)
    begin
        if reset = '1' then
            v_count <= 0;
        elsif rising_edge(clk_25MHz) then  -- Using 50MHz directly
            if h_count = H_TOTAL - 1 then
                if v_count = V_TOTAL - 1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Generate sync signals with proper polarity
    -- Horizontal sync pulse is negative
    h_sync <= '0' when h_count >= H_DISPLAY + H_FRONT_PORCH and 
                      h_count < H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE else '1';
    
    -- Vertical sync pulse is negative              
    v_sync <= '0' when v_count >= V_DISPLAY + V_FRONT_PORCH and 
                      v_count < V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE else '1';
    
    -- Generate display active signals
    h_display_active <= '1' when h_count < H_DISPLAY else '0';
    v_display_active <= '1' when v_count < V_DISPLAY else '0';
    
    -- Output display enable signal and pixel coordinates
    display_enable <= h_display_active and v_display_active;
    
    -- Output current pixel coordinates
    column <= h_count when h_display_active = '1' else 0;
    row <= v_count when v_display_active = '1' else 0;
    
end Behavioral; 
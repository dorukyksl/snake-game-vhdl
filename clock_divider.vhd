library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clock_divider is
    Port ( 
        clk_in : in STD_LOGIC;   -- 100 MHz
        reset : in STD_LOGIC;
        clk_vga : out STD_LOGIC;   -- VGA Clock (50MHz)
        clk_25Hz : out STD_LOGIC    -- Game logic clock
    );
end clock_divider;

architecture Behavioral of clock_divider is
    signal counter_vga : unsigned(0 downto 0) := (others => '0');
    signal counter_25Hz : unsigned(23 downto 0) := (others => '0');
    signal clk_vga_i : std_logic := '0';
    signal clk_25Hz_i : std_logic := '0';
begin
    -- 50 MHz clock generation (100MHz / 2 = 50MHz)
    -- Generate a 50MHz clock for better compatibility with modern monitors
    process(clk_in, reset)
    begin
        if reset = '1' then
            counter_vga <= (others => '0');
            clk_vga_i <= '0';
        elsif rising_edge(clk_in) then
            -- Toggle every cycle to create a 50MHz clock
            counter_vga <= not counter_vga;
            if counter_vga(0) = '1' then
                clk_vga_i <= not clk_vga_i;
            end if;
        end if;
    end process;
    
    -- 25 Hz clock generation (100MHz / 2,000,000 = 25Hz)
    -- Game update rate - allows for 0.04s minimum intervals
    process(clk_in, reset)
    begin
        if reset = '1' then
            counter_25Hz <= (others => '0');
            clk_25Hz_i <= '0';
        elsif rising_edge(clk_in) then
            -- Toggle after counting 2 million cycles for a precise 25Hz
            if counter_25Hz >= 1_999_999 then
                counter_25Hz <= (others => '0');
                clk_25Hz_i <= not clk_25Hz_i;
            else
                counter_25Hz <= counter_25Hz + 1;
            end if;
        end if;
    end process;
    
    -- Output the clock signals
    clk_vga <= clk_vga_i;
    clk_25Hz <= clk_25Hz_i;

end Behavioral; 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lfsr is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        enable : in STD_LOGIC;
        random_num : out STD_LOGIC_VECTOR(7 downto 0)
    );
end lfsr;

architecture Behavioral of lfsr is
    signal lfsr_reg : STD_LOGIC_VECTOR(7 downto 0) := "10101010"; -- Non-zero initial state
    signal feedback : STD_LOGIC;
begin
    -- 8-bit Maximal LFSR with taps at bits 7, 5, 4, and 3
    feedback <= lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3);
    
    process(clk, reset)
    begin
        if reset = '1' then
            lfsr_reg <= "10101010"; -- Reset to initial non-zero state
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Shift right and insert feedback bit at MSB
                lfsr_reg <= feedback & lfsr_reg(7 downto 1);
            end if;
        end if;
    end process;
    
    random_num <= lfsr_reg;
    
end Behavioral; 
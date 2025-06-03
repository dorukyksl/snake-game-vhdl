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
begin
    
    process(clk, reset)
        variable feedback : std_logic;
    begin
        if reset = '1' then
            lfsr_reg <= "10101010"; -- Reset to initial non-zero state
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Compute feedback from taps 7,5,4,3 and shift
                feedback := lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3);
                lfsr_reg <= feedback & lfsr_reg(7 downto 1);
            end if;
        end if;
    end process;
    
    random_num <= lfsr_reg;
    
end Behavioral;

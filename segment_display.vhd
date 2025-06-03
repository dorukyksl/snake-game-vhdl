library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity segment_display is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        score : in INTEGER range 0 to 999;
        seg : out STD_LOGIC_VECTOR(6 downto 0);
        an : out STD_LOGIC_VECTOR(3 downto 0)
    );
end segment_display;

architecture Behavioral of segment_display is
    -- For digit multiplexing
    signal display_count : unsigned(16 downto 0) := (others => '0');
    signal active_digit : std_logic_vector(1 downto 0) := "00";
    
    -- BCD digits
    signal hundreds, tens, ones : INTEGER range 0 to 9 := 0;
    
    -- Current digit to display
    signal digit_value : INTEGER range 0 to 9 := 0;
    
    -- 7-segment encoding for 0-9 (active low)
    type segment_array is array(0 to 9) of std_logic_vector(6 downto 0);
    constant segments : segment_array := (
        "1000000", -- 0
        "1111001", -- 1
        "0100100", -- 2
        "0110000", -- 3
        "0011001", -- 4
        "0010010", -- 5
        "0000010", -- 6
        "1111000", -- 7
        "0000000", -- 8
        "0010000"  -- 9
    );
begin
    -- Digit multiplexing process
    process(clk, reset)
    begin
        if reset = '1' then
            display_count <= (others => '0');
        elsif rising_edge(clk) then
            display_count <= display_count + 1;
        end if;
    end process;
    
    -- Extract the upper 2 bits to control digit selection
    active_digit <= std_logic_vector(display_count(16 downto 15));
    
    -- Convert score to BCD representation
    process(score)
        variable temp : INTEGER range 0 to 999;
    begin
        temp := score;
        hundreds <= temp / 100;
        temp := temp mod 100;
        tens <= temp / 10;
        ones <= temp mod 10;
    end process;
    
    -- Select which digit to display
    process(active_digit, hundreds, tens, ones)
    begin
        case active_digit is
            when "00" => 
                -- Rightmost digit (ones)
                digit_value <= ones;
                an <= "1110";
            when "01" => 
                -- Second digit from right (tens)
                digit_value <= tens;
                an <= "1101";
            when "10" => 
                -- Third digit from right (hundreds)
                digit_value <= hundreds;
                an <= "1011";
            when others => 
                -- Leftmost digit (not used)
                digit_value <= 0;
                an <= "0111";
        end case;
    end process;
    
    -- Set the segment signals based on digit value
    seg <= segments(digit_value);
    
end Behavioral; 
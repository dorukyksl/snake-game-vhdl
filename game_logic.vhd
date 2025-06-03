library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_logic is
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
end game_logic;

architecture Behavioral of game_logic is
    -- Game constants
    constant MAX_SNAKE_LENGTH : integer := 100;
    constant CELL_SIZE : integer := 16; -- 16x16 pixels per cell
    constant GRID_WIDTH : integer := 40; -- 40 columns
    constant GRID_HEIGHT : integer := 30; -- 30 rows
    constant BORDER_THICKNESS : integer := 1; -- Border thickness for snake cells
    
    -- Score display constants
    constant SCORE_X_POS : integer := 500; -- X position for score display
    constant SCORE_Y_POS : integer := 20;  -- Y position for score display
    
    -- PAUSED display constants
    constant PAUSED_X_POS : integer := 250; -- X position for PAUSED display
    constant PAUSED_Y_POS : integer := 240; -- Y position for PAUSED display (center)
    
    -- GAME OVER display constants
    constant GAMEOVER_X_POS : integer := 120;
    constant GAMEOVER_Y_POS : integer := 220;
    
    -- Difficulty display constants
    constant DIFFICULTY_X_POS : integer := 10;   -- Top-left corner
    constant DIFFICULTY_Y_POS : integer := 10;
    constant DIFFICULTY_BAR_X : integer := 100;  -- Bars start position
    constant DIFFICULTY_BAR_Y : integer := 10;
    constant BAR_WIDTH : integer := 12;          -- Each bar width
    constant BAR_HEIGHT : integer := 8;          -- Bar height
    constant BAR_SPACING : integer := 2;         -- Space between bars
    
    -- Startup screen constants and letter ROM helper
    constant START_TITLE : string := "SNAKE GAME"; -- 10 characters including space
    constant START_PROMPT : string := "PRESS ANY KEY TO BEGIN"; -- 22 characters including spaces
    constant START_TITLE_LEN : integer := 10;
    constant START_PROMPT_LEN : integer := 22;
    -- Positioning for startup screen (centered approximation)
    constant START_TITLE_X : integer := 280;  -- (640 - 80) / 2  (10 chars * 8 px)
    constant START_TITLE_Y : integer := 150;
    constant START_PROMPT_X : integer := 254; -- (640 - 132) / 2 (22 chars * 6 px)
    constant START_PROMPT_Y : integer := 200;
    
    -- Game state types
    type state_type is (IDLE, PLAYING, PAUSED, GAME_OVER);
    signal game_state : state_type := IDLE;
    
    -- Snake direction type and signal
    type direction_type is (UP, DOWN, LEFT, RIGHT);
    signal current_direction : direction_type := RIGHT;
    signal next_direction : direction_type := RIGHT;
    
    -- Snake segments type and signals
    type point is record
        x : integer range 0 to GRID_WIDTH-1;
        y : integer range 0 to GRID_HEIGHT-1;
    end record;
    
    type snake_array is array (0 to MAX_SNAKE_LENGTH-1) of point;
    signal snake : snake_array := (others => (0, 0));
    signal snake_length : integer range 0 to MAX_SNAKE_LENGTH := 3;
    
    -- Food position
    signal food_pos : point := (20, 15);
    
    -- Poison fruit position (appears from level 2)
    signal poison_fruit_pos : point := (10, 10);
    signal poison_fruit_active : boolean := false;
    
    -- Score tracking
    signal current_score : integer range 0 to 999 := 0;
    
    -- Difficulty system
    signal difficulty_level : integer range 1 to 5 := 1;
    signal game_speed_counter : integer range 0 to 15 := 0;
    signal speed_threshold : integer range 1 to 15 := 8;  -- Başlangıç hızı (0.3s @ 25Hz)
    
    -- Game grid representation for rendering
    -- 000:empty, 001:snake, 010:food, 011:poison_fruit, 100:snake_border, 101:score_text, 110:score_background, 111:paused_text
    signal grid_pixel : std_logic_vector(2 downto 0) := "000";
    
    -- Character ROM definitions
    type char_rom_type is array(0 to 9) of std_logic_vector(0 to 34);
    constant CHAR_ROM : char_rom_type := (
        -- 0
        "00111" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "00111",
        
        -- 1
        "00010" &
        "00110" &
        "00010" &
        "00010" &
        "00010" &
        "00010" &
        "00111",
        
        -- 2
        "00111" &
        "01001" &
        "00001" &
        "00010" &
        "00100" &
        "01000" &
        "01111",
        
        -- 3
        "00111" &
        "01001" &
        "00001" &
        "00111" &
        "00001" &
        "01001" &
        "00111",
        
        -- 4
        "00001" &
        "00011" &
        "00101" &
        "01001" &
        "01111" &
        "00001" &
        "00001",
        
        -- 5
        "01111" &
        "01000" &
        "01000" &
        "01111" &
        "00001" &
        "01001" &
        "00111",
        
        -- 6
        "00111" &
        "01000" &
        "01000" &
        "01111" &
        "01001" &
        "01001" &
        "00111",
        
        -- 7
        "01111" &
        "00001" &
        "00001" &
        "00010" &
        "00100" &
        "00100" &
        "00100",
        
        -- 8
        "00111" &
        "01001" &
        "01001" &
        "00111" &
        "01001" &
        "01001" &
        "00111",
        
        -- 9
        "00111" &
        "01001" &
        "01001" &
        "00111" &
        "00001" &
        "00001" &
        "00111"
    );
    
    -- Letter ROM for "SCORE:"
    type letter_rom_type is array(0 to 5) of std_logic_vector(0 to 34);
    constant LETTER_ROM : letter_rom_type := (
        -- S
        "00111" &
        "01000" &
        "01000" &
        "00110" &
        "00001" &
        "00001" &
        "01110",
        
        -- C
        "00111" &
        "01000" &
        "01000" &
        "01000" &
        "01000" &
        "01000" &
        "00111",
        
        -- O
        "00111" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "00111",
        
        -- R
        "01110" &
        "01001" &
        "01001" &
        "01110" &
        "01010" &
        "01001" &
        "01001",
        
        -- E
        "01111" &
        "01000" &
        "01000" &
        "01110" &
        "01000" &
        "01000" &
        "01111",
        
        -- : (colon)
        "00000" &
        "00100" &
        "00100" &
        "00000" &
        "00100" &
        "00100" &
        "00000"
    );
    
    -- PAUSED ROM for "PAUSED"
    type paused_rom_type is array(0 to 5) of std_logic_vector(0 to 34);
    constant PAUSED_ROM : paused_rom_type := (
        -- P
        "01111" &
        "01001" &
        "01001" &
        "01111" &
        "01000" &
        "01000" &
        "01000",
        
        -- A
        "00111" &
        "01001" &
        "01001" &
        "01111" &
        "01001" &
        "01001" &
        "01001",
        
        -- U
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "00111",
        
        -- S
        "00111" &
        "01000" &
        "01000" &
        "00110" &
        "00001" &
        "00001" &
        "01110",
        
        -- E
        "01111" &
        "01000" &
        "01000" &
        "01110" &
        "01000" &
        "01000" &
        "01111",
        
        -- D
        "01110" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "01001" &
        "01110"
    );
    
    -- GAME OVER ROM (9 characters: G A M E <space> O V E R)
    type gameover_rom_type is array(0 to 8) of std_logic_vector(0 to 34);
    constant GAMEOVER_ROM : gameover_rom_type := (
        -- G
        "01110" &
        "10001" &
        "10000" &
        "10111" &
        "10001" &
        "10001" &
        "01110",
        -- A
        "00100" &
        "01010" &
        "10001" &
        "11111" &
        "10001" &
        "10001" &
        "10001",
        -- M
        "10001" &
        "11011" &
        "10101" &
        "10101" &
        "10001" &
        "10001" &
        "10001",
        -- E
        "11111" &
        "10000" &
        "10000" &
        "11110" &
        "10000" &
        "10000" &
        "11111",
        -- space (blank)
        "00000" &
        "00000" &
        "00000" &
        "00000" &
        "00000" &
        "00000" &
        "00000",
        -- O
        "01110" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "01110",
        -- V
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "01010" &
        "00100",
        -- E
        "11111" &
        "10000" &
        "10000" &
        "11110" &
        "10000" &
        "10000" &
        "11111",
        -- R
        "01110" &
        "10001" &
        "10001" &
        "01110" &
        "10100" &
        "10010" &
        "10001"
    );
    
    -- DIFFICULTY ROM for "DIFFICULTY" (10 characters)
    type difficulty_rom_type is array(0 to 9) of std_logic_vector(0 to 34);
    constant DIFFICULTY_ROM : difficulty_rom_type := (
        -- D
        "11110" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "11110",
        -- I
        "11111" &
        "00100" &
        "00100" &
        "00100" &
        "00100" &
        "00100" &
        "11111",
        -- F
        "11111" &
        "10000" &
        "10000" &
        "11110" &
        "10000" &
        "10000" &
        "10000",
        -- F
        "11111" &
        "10000" &
        "10000" &
        "11110" &
        "10000" &
        "10000" &
        "10000",
        -- I
        "11111" &
        "00100" &
        "00100" &
        "00100" &
        "00100" &
        "00100" &
        "11111",
        -- C
        "01111" &
        "10000" &
        "10000" &
        "10000" &
        "10000" &
        "10000" &
        "01111",
        -- U
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "10001" &
        "01110",
        -- L
        "10000" &
        "10000" &
        "10000" &
        "10000" &
        "10000" &
        "10000" &
        "11111",
        -- T
        "11111" &
        "00100" &
        "00100" &
        "00100" &
        "00100" &
        "00100" &
        "00100",
        -- Y
        "10001" &
        "10001" &
        "01010" &
        "00100" &
        "00100" &
        "00100" &
        "00100"
    );
    
    -- Snake Head Sprite (16x16) - Simple clean snake face
    type snake_head_rom_type is array(0 to 15) of std_logic_vector(0 to 15);
    constant SNAKE_HEAD_ROM : snake_head_rom_type := (
        "0000000000000000", -- Row 0
        "0000111111110000", -- Row 1 - head start
        "0001111111111000", -- Row 2 - head expanding
        "0011111111111100", -- Row 3 - wider head
        "0111111111111110", -- Row 4 - full head
        "1111011111011111", -- Row 5 - bigger eyes
        "1111111111111111", -- Row 6 - full face
        "1111111111111111", -- Row 7 - full face
        "1111111111111111", -- Row 8 - full face
        "0111111111111110", -- Row 9 - face narrowing
        "0111111111111110", -- Row 10 - neck
        "0011111111111100", -- Row 11 - neck narrowing
        "0011111111111100", -- Row 12 - body connection
        "0001111111111000", -- Row 13 - body connection
        "0001111111111000", -- Row 14 - body connection
        "0000111111110000"  -- Row 15 - body connection
    );
    
    -- Snake Body Sprite (16x16) - Clean pixel art style
    type snake_body_rom_type is array(0 to 15) of std_logic_vector(0 to 15);
    constant SNAKE_BODY_ROM : snake_body_rom_type := (
        "0000111111110000", -- Row 0
        "0011111111111100", -- Row 1
        "0111111111111110", -- Row 2
        "1111111111111111", -- Row 3
        "1111011011011111", -- Row 4 - simple scale pattern
        "1110111111101111", -- Row 5 - diamond scales
        "1111111111111111", -- Row 6
        "1111111111111111", -- Row 7
        "1111111111111111", -- Row 8
        "1111111111111111", -- Row 9
        "1110111111101111", -- Row 10 - diamond scales
        "1111011011011111", -- Row 11 - simple scale pattern
        "1111111111111111", -- Row 12
        "0111111111111110", -- Row 13
        "0011111111111100", -- Row 14
        "0000111111110000"  -- Row 15
    );
    
    -- Mouse Sprite (16x16) - Cute pixel art style
    type mouse_rom_type is array(0 to 15) of std_logic_vector(0 to 15);
    constant MOUSE_ROM : mouse_rom_type := (
        "0000000000000000", -- Row 0
        "0011000000001100", -- Row 1 - round ears
        "0111100000011110", -- Row 2 - ear outline
        "0111111111111110", -- Row 3 - head start
        "1111111111111111", -- Row 4 - full head
        "1111111111111111", -- Row 5 - head
        "1111100000111111", -- Row 6 - small cute eyes
        "1111111111111111", -- Row 7 - face
        "1111111111111111", -- Row 8 - cheeks
        "0111111111111110", -- Row 9 - face bottom
        "0011111111111100", -- Row 10 - body top
        "0011111111111100", -- Row 11 - body
        "0011111111111100", -- Row 12 - body
        "0001111111111000", -- Row 13 - body bottom
        "0000011111100000", -- Row 14 - small tail
        "0000000000000000"  -- Row 15
    );
    
    -- Poison Fruit Sprite (16x16) - Dangerous looking fruit
    type poison_fruit_rom_type is array(0 to 15) of std_logic_vector(0 to 15);
    constant POISON_FRUIT_ROM : poison_fruit_rom_type := (
        "0000000000000000", -- Row 0
        "0000001111000000", -- Row 1 - stem
        "0000011111100000", -- Row 2 - stem wider
        "0001111111111000", -- Row 3 - fruit top
        "0011111111111100", -- Row 4 - expanding
        "0111111111111110", -- Row 5 - full width
        "1111100000111111", -- Row 6 - poison skull eyes!
        "1111111111111111", -- Row 7 - face
        "1111110110111111", -- Row 8 - skull nose
        "1111111111111111", -- Row 9 - menacing face
        "0111111111111110", -- Row 10 - fruit body
        "0111111111111110", -- Row 11 - fruit body
        "0011111111111100", -- Row 12 - narrowing
        "0001111111111000", -- Row 13 - bottom
        "0000011111100000", -- Row 14 - tip
        "0000000000000000"  -- Row 15
    );
    
    -- Helper function to check if point is in snake
    function is_point_in_snake(p: point; s: snake_array; len: integer) return boolean is
        variable found : boolean := false;
    begin
        -- Use a fixed loop with condition inside
        for i in 0 to MAX_SNAKE_LENGTH-1 loop
            if i < len then
                if s(i).x = p.x and s(i).y = p.y then
                    found := true;
                end if;
            end if;
        end loop;
        return found;
    end function;
    
    -- Function to get sprite pixel value (returns 1 if sprite pixel should be drawn, 0 if transparent)
    function get_snake_sprite_pixel(pixel_x, pixel_y: integer; is_head: boolean) return std_logic is
        variable sprite_x : integer := pixel_x mod CELL_SIZE;
        variable sprite_y : integer := pixel_y mod CELL_SIZE;
    begin
        if is_head then
            return SNAKE_HEAD_ROM(sprite_y)(sprite_x);
        else
            return SNAKE_BODY_ROM(sprite_y)(sprite_x);
        end if;
    end function;
    
    -- Function to get mouse sprite pixel value
    function get_mouse_sprite_pixel(pixel_x, pixel_y: integer) return std_logic is
        variable sprite_x : integer := pixel_x mod CELL_SIZE;
        variable sprite_y : integer := pixel_y mod CELL_SIZE;
    begin
        return MOUSE_ROM(sprite_y)(sprite_x);
    end function;
    
    -- Function to get poison fruit sprite pixel value
    function get_poison_fruit_sprite_pixel(pixel_x, pixel_y: integer) return std_logic is
        variable sprite_x : integer := pixel_x mod CELL_SIZE;
        variable sprite_y : integer := pixel_y mod CELL_SIZE;
    begin
        return POISON_FRUIT_ROM(sprite_y)(sprite_x);
    end function;
    
    -- Simplified function to check if pixel is part of the score display
    function is_score_display(x, y: integer; score_val: integer) return std_logic_vector is
        variable hundreds, tens, ones : integer;
        variable char_index : integer := 0;
        variable bit_pos : integer := 0;
        variable rel_x : integer := 0;
        variable rel_y : integer := 0;
        variable letters_width : integer := 6 * 6; -- 6 letters, each 6 pixels wide
        variable result : std_logic_vector(2 downto 0) := "000";
        variable tens_pos_x : integer := 0; -- X position for tens digit
        variable ones_pos_x : integer := 0; -- X position for ones digit
    begin
        -- Extract digits
        hundreds := score_val / 100;
        tens := (score_val mod 100) / 10;
        ones := score_val mod 10;
        
        -- Calculate positions for digits based on hundreds value
        if hundreds > 0 then
            tens_pos_x := SCORE_X_POS + letters_width + 12;
            ones_pos_x := SCORE_X_POS + letters_width + 18;
        elsif tens > 0 then
            tens_pos_x := SCORE_X_POS + letters_width + 6;
            ones_pos_x := SCORE_X_POS + letters_width + 12;
        else
            ones_pos_x := SCORE_X_POS + letters_width + 6;
        end if;
        
        -- Check if pixel is in the score display area
        if y >= SCORE_Y_POS and y < SCORE_Y_POS + 7 then
            rel_y := y - SCORE_Y_POS;
            
            -- "SCORE:" area (6 characters, each 6 pixels wide)
            if x >= SCORE_X_POS and x < SCORE_X_POS + letters_width then
                rel_x := x - SCORE_X_POS;
                char_index := rel_x / 6; -- Which character
                bit_pos := rel_x mod 6; -- Position within character
                
                if char_index < 6 then -- Make sure we don't go out of bounds
                    -- Check if this pixel is part of the character or background
                    if LETTER_ROM(char_index)(rel_y * 5 + bit_pos) = '1' then
                        result := "101"; -- Score text (actual character pixel)
                    else
                        result := "110"; -- Score background
                    end if;
                end if;
            
            -- Hundreds digit area (only if score >= 100)
            elsif hundreds > 0 and x >= SCORE_X_POS + letters_width + 6 and x < SCORE_X_POS + letters_width + 12 then
                rel_x := x - (SCORE_X_POS + letters_width + 6);
                
                -- Check if this pixel is part of the digit or background
                if CHAR_ROM(hundreds)(rel_y * 5 + rel_x) = '1' then
                    result := "101"; -- Score digit (actual digit pixel)
                else
                    result := "110"; -- Score background
                end if;
            
            -- Tens digit area (show always for scores >= 10, or show zero if score >= 100)
            elsif (tens > 0 or hundreds > 0) and x >= tens_pos_x and x < tens_pos_x + 6 then
                rel_x := x - tens_pos_x;
                
                -- Check if this pixel is part of the digit or background
                if CHAR_ROM(tens)(rel_y * 5 + rel_x) = '1' then
                    result := "101"; -- Score digit (actual digit pixel)
                else
                    result := "110"; -- Score background
                end if;
            
            -- Ones digit area (always show)
            elsif x >= ones_pos_x and x < ones_pos_x + 6 then
                rel_x := x - ones_pos_x;
                
                -- Check if this pixel is part of the digit or background
                if CHAR_ROM(ones)(rel_y * 5 + rel_x) = '1' then
                    result := "101"; -- Score digit (actual digit pixel)
                else
                    result := "110"; -- Score background
                end if;
            end if;
        end if;
        
        return result;
    end function;
    
    -- Simplified function to check if pixel is part of the PAUSED display
    function is_paused_display(x, y: integer) return std_logic_vector is
        variable char_index : integer := 0;
        variable bit_pos : integer := 0;
        variable rel_x : integer := 0;
        variable rel_y : integer := 0;
        variable letters_width : integer := 6 * 8; -- 6 letters, each 8 pixels wide (with spacing)
        variable result : std_logic_vector(2 downto 0) := "000";
    begin
        -- Check if pixel is in the PAUSED display area
        if y >= PAUSED_Y_POS and y < PAUSED_Y_POS + 7 then
            rel_y := y - PAUSED_Y_POS;
            
            -- "PAUSED" area (6 characters, each 8 pixels wide with spacing)
            if x >= PAUSED_X_POS and x < PAUSED_X_POS + letters_width then
                rel_x := x - PAUSED_X_POS;
                char_index := rel_x / 8; -- Which character (8 pixels spacing)
                bit_pos := rel_x mod 8; -- Position within character
                
                if char_index < 6 and bit_pos < 5 then -- Make sure we don't go out of bounds
                    -- Check if this pixel is part of the character
                    if PAUSED_ROM(char_index)(rel_y * 5 + bit_pos) = '1' then
                        result := "111"; -- PAUSED text
                    end if;
                end if;
            end if;
        end if;
        
        return result;
    end function;
    
    -- Function to check if pixel is part of the GAME OVER display
    function is_gameover_display(x, y: integer) return std_logic_vector is
        variable char_index : integer := 0;
        variable bit_pos : integer := 0;
        variable rel_x : integer := 0;
        variable rel_y : integer := 0;
        variable letters_width : integer := 9 * 8; -- 9 characters, 8 pixels wide (5 + 3 spacing)
        variable result : std_logic_vector(2 downto 0) := "000";
    begin
        -- Check if pixel is in the GAME OVER display area
        if y >= GAMEOVER_Y_POS and y < GAMEOVER_Y_POS + 7 then
            rel_y := y - GAMEOVER_Y_POS;
            
            if x >= GAMEOVER_X_POS and x < GAMEOVER_X_POS + letters_width then
                rel_x := x - GAMEOVER_X_POS;
                char_index := rel_x / 8; -- Which character (8px spacing)
                bit_pos := rel_x mod 8;   -- Position within character
                
                if char_index < 9 and bit_pos < 5 then
                    if GAMEOVER_ROM(char_index)(rel_y * 5 + bit_pos) = '1' then
                        result := "111"; -- Use same yellow as PAUSED
                    end if;
                end if;
            end if;
        end if;
        return result;
    end function;
    
    -- Function to check if pixel is part of the difficulty display
    function is_difficulty_display(x, y: integer; diff_level: integer) return std_logic_vector is
        variable char_index : integer := 0;
        variable bit_pos : integer := 0;
        variable rel_x : integer := 0;
        variable rel_y : integer := 0;
        variable bar_index : integer := 0;
        variable bar_x : integer := 0;
        variable result : std_logic_vector(2 downto 0) := "000";
    begin
        -- Check if pixel is in the difficulty text area
        if y >= DIFFICULTY_Y_POS and y < DIFFICULTY_Y_POS + 7 then
            rel_y := y - DIFFICULTY_Y_POS;
            
            -- "DIFFICULTY" text area (10 characters, 6 pixels wide each)
            if x >= DIFFICULTY_X_POS and x < DIFFICULTY_X_POS + 60 then
                rel_x := x - DIFFICULTY_X_POS;
                char_index := rel_x / 6; -- Which character
                bit_pos := rel_x mod 6;  -- Position within character
                
                if char_index < 10 and bit_pos < 5 then
                    if DIFFICULTY_ROM(char_index)(rel_y * 5 + bit_pos) = '1' then
                        result := "101"; -- Blue text like score
                    end if;
                end if;
            end if;
        end if;
        
        -- Check if pixel is in the difficulty bars area
        if y >= DIFFICULTY_BAR_Y and y < DIFFICULTY_BAR_Y + BAR_HEIGHT then
            for i in 1 to 5 loop
                bar_x := DIFFICULTY_BAR_X + (i-1) * (BAR_WIDTH + BAR_SPACING);
                if x >= bar_x and x < bar_x + BAR_WIDTH then
                    if i <= diff_level then
                        result := "101"; -- Filled bar (blue)
                    else
                        result := "110"; -- Empty bar (black background)
                    end if;
                end if;
            end loop;
        end if;
        
        return result;
    end function;
    
    -- Function that returns 5x7 letter ROM for given uppercase character
    function get_startup_letter_rom(ch: character) return std_logic_vector is
    begin
        case ch is
            when 'A' => return PAUSED_ROM(1);
            when 'B' => return "11110" & "10001" & "10001" & "11110" & "10001" & "10001" & "11110";
            when 'C' => return DIFFICULTY_ROM(5); -- C
            when 'D' => return PAUSED_ROM(5);
            when 'E' => return PAUSED_ROM(4);
            when 'G' => return GAMEOVER_ROM(0);
            when 'I' => return DIFFICULTY_ROM(1);
            when 'K' => return "10001" & "10010" & "10100" & "11000" & "10100" & "10010" & "10001";
            when 'L' => return DIFFICULTY_ROM(7);
            when 'M' => return GAMEOVER_ROM(2);
            when 'N' => return "10001" & "11001" & "10101" & "10011" & "10001" & "10001" & "10001";
            when 'O' => return GAMEOVER_ROM(5);
            when 'P' => return PAUSED_ROM(0);
            when 'R' => return GAMEOVER_ROM(8);
            when 'S' => return PAUSED_ROM(3);
            when 'T' => return DIFFICULTY_ROM(8);
            when 'U' => return PAUSED_ROM(2);
            when 'V' => return GAMEOVER_ROM(6);
            when 'Y' => return DIFFICULTY_ROM(9);
            when others => return (others => '0'); -- Space or undefined
        end case;
    end function;

    -- Function to determine if current pixel belongs to startup screen text
    function is_startup_display(x, y: integer) return std_logic_vector is
        variable rel_x, rel_y : integer;
        variable char_index : integer;
        variable bit_pos : integer;
        variable result : std_logic_vector(2 downto 0) := "000";
        variable letter_pattern : std_logic_vector(0 to 34);
        variable ch : character;
    begin
        -- First line: "SNAKE GAME" (8-pixel cells, 5-pixel glyph +3-pixel spacing)
        if y >= START_TITLE_Y and y < START_TITLE_Y + 7 then
            rel_y := y - START_TITLE_Y;
            if x >= START_TITLE_X and x < START_TITLE_X + START_TITLE_LEN*8 then
                rel_x := x - START_TITLE_X;
                char_index := rel_x / 8;
                bit_pos := rel_x mod 8;
                if char_index < START_TITLE_LEN and bit_pos < 5 then
                    ch := START_TITLE(char_index+1);
                    letter_pattern := get_startup_letter_rom(ch);
                    if letter_pattern(rel_y*5 + bit_pos) = '1' then
                        result := "111"; -- Yellow large title
                    end if;
                end if;
            end if;
        end if;

        -- Second line: "PRESS ANY KEY TO BEGIN" (6-pixel cells, 5-pixel glyph +1-pixel spacing)
        if y >= START_PROMPT_Y and y < START_PROMPT_Y + 7 then
            rel_y := y - START_PROMPT_Y;
            if x >= START_PROMPT_X and x < START_PROMPT_X + START_PROMPT_LEN*6 then
                rel_x := x - START_PROMPT_X;
                char_index := rel_x / 6;
                bit_pos := rel_x mod 6;
                if char_index < START_PROMPT_LEN and bit_pos < 5 then
                    ch := START_PROMPT(char_index+1);
                    letter_pattern := get_startup_letter_rom(ch);
                    if letter_pattern(rel_y*5 + bit_pos) = '1' then
                        result := "101"; -- Blue prompt text
                    end if;
                end if;
            end if;
        end if;
        return result;
    end function;
    
begin
    -- Main game process
    process(clk_25Hz, reset)
        variable new_head : point;
        variable food_temp : point;
        variable collision : boolean := false;
        -- Toggle edge detection variables
        variable prev_short_toggle : std_logic := '0';
        variable prev_long_toggle  : std_logic := '0';
        variable short_event : std_logic := '0';
        variable long_event  : std_logic := '0';
    begin
        if reset = '1' then
            -- Reset the game
            game_state <= IDLE;
            current_direction <= RIGHT;
            next_direction <= RIGHT;
            snake_length <= 3;
            current_score <= 0;
            -- Initialize snake at the center
            snake(0) <= (5, 15);
            snake(1) <= (4, 15);
            snake(2) <= (3, 15);
            food_pos <= (20, 15);
            -- Initialize poison fruit system
            poison_fruit_pos <= (10, 10);
            poison_fruit_active <= false;
            -- Initialize difficulty system
            difficulty_level <= 1;
            game_speed_counter <= 0;
            speed_threshold <= 8;
            
        elsif rising_edge(clk_25Hz) then
            -- Detect short/long press events from toggle signals
            short_event := '0';
            long_event := '0';
            if short_press /= prev_short_toggle then
                short_event := '1';
                prev_short_toggle := short_press;
            end if;
            if long_press /= prev_long_toggle then
                long_event := '1';
                prev_long_toggle := long_press;
            end if;

            -- Global restart on long_event
            if long_event = '1' then
                -- reinitialize game variables
                current_direction <= RIGHT;
                next_direction <= RIGHT;
                snake_length <= 3;
                current_score <= 0;
                snake(0) <= (5, 15);
                snake(1) <= (4, 15);
                snake(2) <= (3, 15);
                -- random food seed remains
                food_pos <= (20, 15);
                -- Reset poison fruit system
                poison_fruit_pos <= (10, 10);
                poison_fruit_active <= false;
                game_state <= PLAYING;
                -- Reset difficulty system
                difficulty_level <= 1;
                game_speed_counter <= 0;
                speed_threshold <= 8;
            end if;

            -- Update difficulty level based on score
            if current_score >= 200 then
                difficulty_level <= 5;
                speed_threshold <= 1;  -- 0.04s @ 25Hz (1 cycle)
            elsif current_score >= 150 then
                difficulty_level <= 4;
                speed_threshold <= 2;  -- 0.06s @ 25Hz (1.5→2 cycles)
            elsif current_score >= 100 then
                difficulty_level <= 3;
                speed_threshold <= 3;  -- 0.1s @ 25Hz (2.5→3 cycles)
            elsif current_score >= 50 then
                difficulty_level <= 2;
                speed_threshold <= 5;  -- 0.2s @ 25Hz (5 cycles)
            else
                difficulty_level <= 1;
                speed_threshold <= 8;  -- 0.3s @ 25Hz
            end if;
            
            -- Activate poison fruit from level 2 (score >= 50)
            if difficulty_level >= 2 then
                poison_fruit_active <= true;
            else
                poison_fruit_active <= false;
            end if;

            case game_state is
                when IDLE =>
                    -- Wait for any button press to start the game
                    if btn_up = '1' or btn_down = '1' or btn_left = '1' or btn_right = '1' then
                        game_state <= PLAYING;
                    end if;
                    
                when PLAYING =>
                    -- Check for pause/restart first using events
                    if long_event = '1' then
                        game_state <= IDLE;  -- Long press resets game
                    elsif short_event = '1' then
                        game_state <= PAUSED;  -- Short press pauses game
                    else
                        -- Direction changes are always immediate (no delay)
                        if btn_up = '1' and current_direction /= DOWN then
                            next_direction <= UP;
                        elsif btn_down = '1' and current_direction /= UP then
                            next_direction <= DOWN;
                        elsif btn_left = '1' and current_direction /= RIGHT then
                            next_direction <= LEFT;
                        elsif btn_right = '1' and current_direction /= LEFT then
                            next_direction <= RIGHT;
                        end if;
                        
                        -- Speed control: only update snake movement when counter reaches threshold
                        if game_speed_counter >= speed_threshold then
                            game_speed_counter <= 0;
                            
                            -- Update snake position
                            current_direction <= next_direction;
                            
                            -- Calculate new head position
                            new_head := snake(0);
                            
                            case current_direction is
                                when UP =>
                                    if new_head.y = 0 then
                                        new_head.y := GRID_HEIGHT - 1; -- Wrap around
                                    else
                                        new_head.y := new_head.y - 1;
                                    end if;
                                when DOWN =>
                                    if new_head.y = GRID_HEIGHT - 1 then
                                        new_head.y := 0; -- Wrap around
                                    else
                                        new_head.y := new_head.y + 1;
                                    end if;
                                when LEFT =>
                                    if new_head.x = 0 then
                                        new_head.x := GRID_WIDTH - 1; -- Wrap around
                                    else
                                        new_head.x := new_head.x - 1;
                                    end if;
                                when RIGHT =>
                                    if new_head.x = GRID_WIDTH - 1 then
                                        new_head.x := 0; -- Wrap around
                                    else
                                        new_head.x := new_head.x + 1;
                                    end if;
                            end case;
                            
                            -- Check collision with self
                            collision := false;
                            -- Fixed range for loop with condition inside
                            for i in 0 to MAX_SNAKE_LENGTH-2 loop
                                if i < snake_length-1 then
                                    if snake(i).x = new_head.x and snake(i).y = new_head.y then
                                        collision := true;
                                    end if;
                                end if;
                            end loop;
                            
                            if collision then
                                game_state <= GAME_OVER;
                            -- Check collision with poison fruit (if active)
                            elsif poison_fruit_active and new_head.x = poison_fruit_pos.x and new_head.y = poison_fruit_pos.y then
                                game_state <= GAME_OVER;  -- Poison fruit kills instantly!
                            else
                                -- Move snake: shift all segments and add new head
                                -- Use a fixed range for loop with condition inside
                                for i in MAX_SNAKE_LENGTH-1 downto 1 loop
                                    if i < snake_length then
                                        snake(i) <= snake(i-1);
                                    end if;
                                end loop;
                                snake(0) <= new_head;
                                
                                -- Check if food was eaten
                                if new_head.x = food_pos.x and new_head.y = food_pos.y then
                                    -- Increase snake length
                                    if snake_length < MAX_SNAKE_LENGTH then
                                        snake_length <= snake_length + 1;
                                    end if;
                                    
                                    -- Increase score
                                    current_score <= current_score + 10;
                                    
                                    -- Generate new food position (that's not on the snake)
                                    food_temp.x := to_integer(unsigned(random_num(5 downto 0))) mod GRID_WIDTH;
                                    food_temp.y := to_integer(unsigned(random_num(7 downto 2))) mod GRID_HEIGHT;
                                    
                                    -- Ensure food isn't placed on the snake
                                    if not is_point_in_snake(food_temp, snake, snake_length) then
                                        food_pos <= food_temp;
                                    else
                                        -- Simple fallback if random position is on snake
                                        if food_pos.x + 7 < GRID_WIDTH then
                                            food_pos.x <= food_pos.x + 7;
                                        else
                                            food_pos.x <= (food_pos.x + 7) - GRID_WIDTH;
                                        end if;
                                        
                                        if food_pos.y + 11 < GRID_HEIGHT then
                                            food_pos.y <= food_pos.y + 11;
                                        else
                                            food_pos.y <= (food_pos.y + 11) - GRID_HEIGHT;
                                        end if;
                                    end if;
                                    
                                    -- Generate new poison fruit position (if poison fruit is active)
                                    if poison_fruit_active then
                                        -- Generate poison fruit position different from food and snake
                                        food_temp.x := to_integer(unsigned(random_num(3 downto 0))) mod GRID_WIDTH;
                                        food_temp.y := to_integer(unsigned(random_num(6 downto 1))) mod GRID_HEIGHT;
                                        
                                        -- Simple position logic to avoid overlap
                                        if food_temp.x = food_pos.x and food_temp.y = food_pos.y then
                                            -- Move away from food
                                            if food_temp.x + 5 < GRID_WIDTH then
                                                food_temp.x := food_temp.x + 5;
                                            else
                                                food_temp.x := food_temp.x - 5;
                                            end if;
                                        end if;
                                        
                                        poison_fruit_pos <= food_temp;
                                    end if;
                                end if;
                            end if;
                        else
                            -- Increment speed counter when not moving
                            game_speed_counter <= game_speed_counter + 1;
                        end if;
                    end if;
                    
                when PAUSED =>
                    -- Check for unpause/restart using events
                    if long_event = '1' then
                        game_state <= IDLE;  -- Long press resets game
                    elsif short_event = '1' then
                        game_state <= PLAYING;  -- Short press resumes game
                    elsif btn_up = '1' and btn_down = '1' then
                        game_state <= IDLE;  -- Alternative reset method
                    end if;
                    
                when GAME_OVER =>
                    -- Wait for reset button to restart
                    if btn_up = '1' and btn_down = '1' then
                        game_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    
    -- Process to determine what is displayed at current pixel
    process(pixel_x, pixel_y, snake_length, snake, food_pos, poison_fruit_pos, poison_fruit_active, current_score, game_state)
        variable grid_x : integer;
        variable grid_y : integer;
        variable is_snake : boolean := false;
        variable is_snake_border : boolean := false;
        variable pixel_in_cell_x : integer;
        variable pixel_in_cell_y : integer;
        variable score_display_result : std_logic_vector(2 downto 0);
        variable paused_display_result : std_logic_vector(2 downto 0);
        variable gameover_display_result : std_logic_vector(2 downto 0);
        variable difficulty_display_result : std_logic_vector(2 downto 0);
        variable startup_display_result : std_logic_vector(2 downto 0);
    begin
        -- Convert pixel coordinates to grid coordinates
        grid_x := pixel_x / CELL_SIZE;
        grid_y := pixel_y / CELL_SIZE;
        
        -- Calculate relative position within the cell
        pixel_in_cell_x := pixel_x mod CELL_SIZE;
        pixel_in_cell_y := pixel_y mod CELL_SIZE;
        
        -- Check if current pixel is part of the snake
        is_snake := false;
        is_snake_border := false;
        
        -- Use a fixed range for loop with condition inside
        for i in 0 to MAX_SNAKE_LENGTH-1 loop
            if i < snake_length then
                if grid_x = snake(i).x and grid_y = snake(i).y then
                    is_snake := true;
                    
                    -- Use sprite-based rendering instead of simple border check
                    -- Check if this is the head (first segment) or body
                    if i = 0 then
                        -- Snake head - use head sprite
                        if get_snake_sprite_pixel(pixel_x, pixel_y, true) = '1' then
                            is_snake_border := false; -- Head uses sprite, no border
                        else
                            is_snake := false; -- Transparent pixel in head sprite
                        end if;
                    else
                        -- Snake body - use body sprite
                        if get_snake_sprite_pixel(pixel_x, pixel_y, false) = '1' then
                            is_snake_border := false; -- Body uses sprite, no border
                        else
                            is_snake := false; -- Transparent pixel in body sprite
                        end if;
                    end if;
                end if;
            end if;
        end loop;
        
        -- Determine what should be displayed at current pixel
        startup_display_result := is_startup_display(pixel_x, pixel_y);
        score_display_result := is_score_display(pixel_x, pixel_y, current_score);
        paused_display_result := is_paused_display(pixel_x, pixel_y);
        gameover_display_result := is_gameover_display(pixel_x, pixel_y);
        difficulty_display_result := is_difficulty_display(pixel_x, pixel_y, difficulty_level);
        
        if game_state = IDLE and startup_display_result /= "000" then
            grid_pixel <= startup_display_result;
        elsif paused_display_result /= "000" and game_state = PAUSED then
            -- Show PAUSED text when game is paused
            grid_pixel <= paused_display_result;
        elsif score_display_result /= "000" then
            -- Use the result from score display function
            grid_pixel <= score_display_result;
        elsif gameover_display_result /= "000" and game_state = GAME_OVER then
            -- Use the result from GAME OVER display function
            grid_pixel <= gameover_display_result;
        elsif difficulty_display_result /= "000" then
            -- Use the result from difficulty display function
            grid_pixel <= difficulty_display_result;
        elsif is_snake then
            if is_snake_border then
                grid_pixel <= "100"; -- Snake border
            else
                grid_pixel <= "001"; -- Snake
            end if;
        elsif grid_x = food_pos.x and grid_y = food_pos.y then
            -- Use mouse sprite for food
            if get_mouse_sprite_pixel(pixel_x, pixel_y) = '1' then
                grid_pixel <= "010"; -- Mouse sprite pixel
            else
                grid_pixel <= "000"; -- Transparent pixel in mouse sprite
            end if;
        elsif grid_x = poison_fruit_pos.x and grid_y = poison_fruit_pos.y and poison_fruit_active then
            -- Use poison fruit sprite for poison fruit
            if get_poison_fruit_sprite_pixel(pixel_x, pixel_y) = '1' then
                grid_pixel <= "011"; -- Poison fruit sprite pixel
            else
                grid_pixel <= "000"; -- Transparent pixel in poison fruit sprite
            end if;
        else
            grid_pixel <= "000"; -- Empty
        end if;
    end process;
    
    -- Generate RGB output based on grid_pixel
    process(grid_pixel)
    begin
        case grid_pixel is
            when "000" => -- Empty
                rgb_out <= x"0F8"; -- Light Green
            when "001" => -- Snake body (now sprite-based)
                rgb_out <= x"0DD"; -- Slightly darker turquoise
            when "010" => -- Food (now mouse sprite)
                rgb_out <= x"89B"; -- Cute blue-gray like the image
            when "011" => -- Poison fruit
                rgb_out <= x"A04"; -- Dangerous purple/red
            when "100" => -- Snake border (unused now with sprites)
                rgb_out <= x"080"; -- Dark Green
            when "101" => -- Score text (actual character pixels)
                rgb_out <= x"00F"; -- Blue
            when "110" => -- Score background
                rgb_out <= x"0F8"; -- Light Green (same as game background)
            when "111" => -- Paused text
                rgb_out <= x"FF0"; -- Yellow
            when others =>
                rgb_out <= x"000"; -- Black (default)
        end case;
    end process;
    
    -- Output the score
    score <= current_score;
    
end Behavioral;
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.08.2024 10:26:27
-- Design Name: 
-- Module Name: test_frame - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity test_frame is
Port (  clk : in std_logic;
    reset : in std_logic;
    start : in std_logic ;
    out_pixel_data : out std_logic_vector(23 downto 0);
    out_phsync : out std_logic;
    out_pvsync : out std_logic;
    pixel_data_valid: out std_logic );
end test_frame;

architecture Behavioral of test_frame is
constant H_ACTIVE   : integer := 800; -- Horizontal Active Pixels
    constant H_FRONT    : integer := 40;  -- Horizontal Front Porch
    constant H_SYNC     : integer := 128;   -- Horizontal Sync Pulse
    constant H_BACK     : integer := 88;  -- Horizontal Back Porch
    constant V_ACTIVE   : integer := 600;  -- Vertical Active Lines
    constant V_FRONT    : integer := 1;    -- Vertical Front Porch
    constant V_SYNC     : integer := 4;    -- Vertical Sync Pulse
    constant V_BACK     : integer := 23;   -- Vertical Back Porch
    constant FRAME_RATE : integer := 60;   -- Frames Per Second
    signal h_count      : integer range 0 to H_ACTIVE + H_FRONT + H_SYNC + H_BACK - 1 := 0;
    signal v_count      : integer range 0 to V_ACTIVE + V_FRONT + V_SYNC + V_BACK - 1 := 0;
    signal frame_counter: integer range 0 to FRAME_RATE - 1 := 0;
    signal active_video : STD_LOGIC ;
    signal rgb_data : STD_LOGIC_VECTOR ( 23 downto 0 );
    signal rgb_hsync : STD_LOGIC;
    signal rgb_vsync : STD_LOGIC;
begin
process(clk,reset)
        variable temp : unsigned(23 downto 0);
    begin
         if(reset='0') then
                        pixel_data_valid <= '0';
                        temp  := (others => '0');
                        rgb_hsync <= '0';
                        rgb_vsync  <= '0';
            
              
         elsif (rising_edge(clk)) then
            if start = '1' then
                
          
                    if h_count = H_ACTIVE + H_FRONT + H_SYNC + H_BACK - 1 then
                        h_count <= 0;
                    else
                        h_count <= h_count + 1;
                    end if;
            
                    if h_count = H_ACTIVE + H_FRONT + H_SYNC + H_BACK - 1 then
                        if v_count = V_ACTIVE + V_FRONT + V_SYNC + V_BACK - 1 then
                            v_count <= 0;
                            frame_counter <= frame_counter + 1;
                        else
                            v_count <= v_count + 1;
                        end if;
                    end if;  
                

                    if h_count >= H_BACK + H_ACTIVE + H_FRONT and h_count < H_BACK + H_ACTIVE + H_FRONT + H_SYNC then
                        rgb_hsync <= '1';
                    else
                        rgb_hsync <= '0';
                    end if;
           
             
                    if v_count >= V_BACK + V_ACTIVE + V_FRONT and v_count < V_BACK + V_ACTIVE + V_FRONT + V_SYNC then
                        rgb_vsync <= '1';
                    else
                        rgb_vsync <= '0';
                    end if;
                
          
                    if h_count >= H_BACK and h_count < H_BACK + H_ACTIVE and
                        v_count >= V_BACK and v_count < V_BACK + V_ACTIVE then
                        
                        pixel_data_valid <= '1';
                -- RGB generation logic goes here based on h_count, v_count, and frame_counter
                        if (h_count > 87) and (h_count < 354) then
                            if(h_count = 88) then
                                temp := "111111110000000000000000";
                            else     
                                temp := "111111111111111100000000";
                            end if;
                        elsif (h_count >= 354) and (h_count < 620) then
                            temp := "111111110000000011111111";
                        elsif (h_count >= 620) and (h_count < 888) then
                            if(h_count = 887) then
                                temp := "000000000000000011111111";
                            else
                                temp := "000000001111111100000000";
                            end if;
                        else
                            temp := "000000000000000000000000";
                        end if;         
                else
                    pixel_data_valid <= '0';
                    temp := (others => '0');
                end if;
         
         end if;
       end if;
       
    out_pixel_data <= STD_LOGIC_VECTOR(temp); 
    out_phsync <=    rgb_hsync;
    out_pvsync <=    rgb_vsync;
end process;

end Behavioral;




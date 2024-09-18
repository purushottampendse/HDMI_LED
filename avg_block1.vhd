----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.08.2024 17:17:07
-- Design Name: 
-- Module Name: avg_block1 - Behavioral
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


library IEEE;----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.08.2024 10:26:27
-- Design Name: 
-- Module Name: avg_block - Behavioral
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

entity avg_block1 is
  Port ( i_clk : in std_logic;
        i_reset : in std_logic;
        i_pixel_data_to_avg : in std_logic_vector(95 downto 0);
        i_pixel_data_ready_to_avg : in std_logic;
        o_pixel_data_valid :  out std_logic;
        o_pixel_data_last : out std_logic;
        o_pixel_data_avged : out std_logic_vector(31 downto 0));
end avg_block1;

architecture Behavioral of avg_block1 is
    signal i_pixel_data_red1 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_green1 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_blue1 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_red2 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_green2 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_blue2 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_red3 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_green3 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_blue3 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_red4 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_green4 :unsigned(9 downto 0):= (others =>'0');
    signal i_pixel_data_blue4 :unsigned(9 downto 0):= (others =>'0');
    
    signal sum_red_pixels : unsigned(9 downto 0):= (others =>'0');
    signal sum_green_pixels : unsigned(9 downto 0):= (others =>'0');
    signal sum_blue_pixels: unsigned(9 downto 0):= (others =>'0');
    signal sum_fixedpt_red_pixels: unsigned(11 downto 0):= (others =>'0');
    signal sum_fixedpt_green_pixels: unsigned(11 downto 0):= (others =>'0');
    signal sum_fixedpt_blue_pixels: unsigned(11 downto 0):= (others =>'0');
    signal average_fixedpt_red_pixels : unsigned(11 downto 0):= (others =>'0');
    signal average_fixedpt_green_pixels : unsigned(11 downto 0):= (others =>'0');
    signal average_fixedpt_blue_pixels : unsigned(11 downto 0):= (others =>'0');
    signal average_red_pixels : unsigned(7 downto 0):= (others =>'0');
    signal average_green_pixels : unsigned(7 downto 0):= (others =>'0');
    signal average_blue_pixels : unsigned(7 downto 0):= (others =>'0');
    
    signal pixels_averaged_count : integer range 0 to 399 := 0;

begin
    i_pixel_data_red1 <=  "00" & unsigned(i_pixel_data_to_avg(7 downto 0)) ;
    i_pixel_data_green1 <=  "00" & unsigned(i_pixel_data_to_avg(15 downto 8)) ;
    i_pixel_data_blue1 <=  "00" & unsigned(i_pixel_data_to_avg(23 downto 16)) ;
    i_pixel_data_red2 <=  "00" & unsigned(i_pixel_data_to_avg(31 downto 24)) ;
    i_pixel_data_green2 <=  "00" & unsigned(i_pixel_data_to_avg(39 downto 32)) ;
    i_pixel_data_blue2 <=  "00" & unsigned(i_pixel_data_to_avg(47 downto 40)) ;
    i_pixel_data_red3 <=  "00" & unsigned(i_pixel_data_to_avg(55 downto 48)) ;
    i_pixel_data_green3 <=  "00" & unsigned(i_pixel_data_to_avg(63 downto 56)) ;
    i_pixel_data_blue3 <=  "00" & unsigned(i_pixel_data_to_avg(71 downto 64)) ;
    i_pixel_data_red4 <=  "00" & unsigned(i_pixel_data_to_avg(79 downto 72)) ;
    i_pixel_data_green4 <=  "00" & unsigned(i_pixel_data_to_avg(87 downto 80)) ;
    i_pixel_data_blue4 <=  "00" & unsigned(i_pixel_data_to_avg(95 downto 88)) ;
   
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_reset = '0' then
                sum_red_pixels <= (others => '0');
                sum_green_pixels <= (others => '0');
                sum_blue_pixels <= (others => '0');
                pixels_averaged_count <= 0 ;
            elsif i_pixel_data_ready_to_avg = '1' then
                sum_fixedpt_red_pixels <= i_pixel_data_red1 + i_pixel_data_red2 + i_pixel_data_red3 + i_pixel_data_red4;
                sum_fixedpt_green_pixels <= i_pixel_data_green1 + i_pixel_data_green2 + i_pixel_data_green3 + i_pixel_data_green4;
                sum_fixedpt_blue_pixels <= i_pixel_data_blue1 + i_pixel_data_blue2 + i_pixel_data_blue3 + i_pixel_data_blue4;
                pixels_averaged_count <= pixels_averaged_count + 1;
            else 
                sum_red_pixels <= (others => '0');
                sum_green_pixels <= (others => '0');
                sum_blue_pixels <= (others => '0');
                pixels_averaged_count <= 0 ;
 
            end if;
         end if;
    end process;
     
    process(i_clk,i_reset)
    begin
         if rising_edge(i_clk) then
            if i_reset = '0' then
                o_pixel_data_last <= '0';
            elsif pixels_averaged_count = 399 then
                o_pixel_data_last <= '1';
            else 
             o_pixel_data_last <= '0';   
            end if;
         end if;
    end process;
    
    process(i_clk,i_reset)
    begin
        if rising_edge(i_clk) then
             if i_reset = '0' then
                o_pixel_data_valid <= '0';
             else
                o_pixel_data_valid <= i_pixel_data_ready_to_avg;
             end if;
         end if;
    end process;
            
    
    
--    sum_fixedpt_red_pixels <= sum_red_pixels(9 downto 0) & '0' & '0';
--    sum_fixedpt_green_pixels<= sum_green_pixels(9 downto 0) & '0' & '0';
--    sum_fixedpt_blue_pixels<= sum_blue_pixels(9 downto 0) & '0' & '0';
    
    average_fixedpt_red_pixels <= '0' & '0' & sum_fixedpt_red_pixels(11 downto 2 ); 
    average_fixedpt_green_pixels <= '0' & '0' & sum_fixedpt_green_pixels(11 downto 2 );
    average_fixedpt_blue_pixels <= '0' & '0' & sum_fixedpt_blue_pixels(11 downto 2 );
    
    average_red_pixels <= average_fixedpt_red_pixels(9 downto 2);
    average_green_pixels <= average_fixedpt_green_pixels(9 downto 2);
    average_blue_pixels <= average_fixedpt_blue_pixels(9 downto 2);
    
     
    o_pixel_data_avged <= "00000000" & std_logic_vector(average_blue_pixels(7 downto 0)) & std_logic_vector(average_green_pixels(7 downto 0))&std_logic_vector(average_red_pixels(7 downto 0));
    --o_pixel_data_valid <= i_pixel_data_ready_to_avg;
end Behavioral;





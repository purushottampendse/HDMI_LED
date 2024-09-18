----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.08.2024 10:26:27
-- Design Name: 
-- Module Name: c_line_buff - Behavioral
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

entity c_line_buff is
Port (i_clk : in std_logic;
        i_reset : in std_logic;
        i_pixel_data : in std_logic_vector(23 downto 0);
        i_pixel_data_active : in std_logic;
        o_pixel_data_to_avg : out std_logic_vector(95 downto 0);
        o_pixel_data_ready_to_avg : out std_logic );
end c_line_buff;

architecture Behavioral of c_line_buff is

type buffer_array is array (natural range <>) of std_logic_vector(23 downto 0);
    signal circ_line_buffer : buffer_array(0 to 2399):= (others => (others => '0'));
    signal clb_write_idx :  integer range 0 to 2399 := 0;
    signal pixels_ready_to_read : integer range 0 to 1599 := 0;
    signal clb_read_idx :  integer range 0 to 2399 := 0;
    signal o_pixel_data_ready_to_avg_sig : std_logic := '0';
    signal pixels_ready_to_read_start_sig : std_logic := '0';
    signal count :integer range 0 to 399 := 0;
    --signal read_ready : std_logic := '0';
begin
    
    CLB_WRITE: process(i_clk, i_reset)  
    begin
        if (rising_edge(i_clk)) then
            if i_reset = '0' then
                circ_line_buffer(clb_write_idx) <= (others => '0');
                clb_write_idx <= 0;
                pixels_ready_to_read_start_sig <= '0';
                
            elsif i_pixel_data_active = '1' then
				circ_line_buffer(clb_write_idx) <= std_logic_vector(i_pixel_data);
				pixels_ready_to_read_start_sig <= '1';
                if clb_write_idx < 2399 then
                    clb_write_idx <= clb_write_idx + 1;
                else
                    clb_write_idx <= 0;
                end if; 
            elsif i_pixel_data_active  = '0' then
                pixels_ready_to_read_start_sig <= '0';
                if clb_write_idx > 2399 then
                    clb_write_idx <= 0;
                else
                    clb_write_idx <= clb_write_idx;            
                end if;
            end if;
        end if;
    end process;
    
    GEN_DATARDY: process(i_clk, i_reset)
    --variable  pixels_ready_to_read : integer range 0 to 1599 := 0;
    --variable  count :integer range 0 to 399 := 0;
     begin
        if (rising_edge(i_clk)) then
            if i_reset = '0' then
                pixels_ready_to_read <= 0;
                o_pixel_data_ready_to_avg_sig <= '0';
                count <= 0;
            elsif pixels_ready_to_read_start_sig = '1' then
                if pixels_ready_to_read < 1600 then
                    pixels_ready_to_read <= pixels_ready_to_read + 1;
                else
                    pixels_ready_to_read <=0;
                end if;
            elsif  pixels_ready_to_read > 1599 then
                pixels_ready_to_read <= 0;   
            end if;
            

            if pixels_ready_to_read = 1600 then
                o_pixel_data_ready_to_avg_sig <= '1';
            elsif count < 399 and o_pixel_data_ready_to_avg_sig = '1' then
                o_pixel_data_ready_to_avg_sig <= '1';
                count <= count +1;
            else
                o_pixel_data_ready_to_avg_sig <= '0';
                count <= 0;
            end if;
        o_pixel_data_ready_to_avg <= o_pixel_data_ready_to_avg_sig;    
        end if;
        
    end process;
    
    --o_pixel_data_ready_to_avg <= o_pixel_data_ready_to_avg_sig;
    
        CLB_READ: process(i_clk,i_reset)
    begin
        if (rising_edge(i_clk)) then
           if i_reset = '0' then
                o_pixel_data_to_avg <= (others => '0');
                clb_read_idx <= 0;
              
           elsif  o_pixel_data_ready_to_avg_sig = '1'  then
               if clb_read_idx >= 0 and clb_read_idx < 801 then
                    o_pixel_data_to_avg <= circ_line_buffer((clb_read_idx)) & circ_line_buffer((clb_read_idx +1))& circ_line_buffer((clb_read_idx + 800)) &circ_line_buffer((clb_read_idx + 801));
                    if clb_read_idx = 798 then
                       clb_read_idx <= 1600;
                    else 
                       clb_read_idx <= clb_read_idx +2;
                    end if;
                    
               elsif clb_read_idx >= 1600 and clb_read_idx < 2401 then
                    o_pixel_data_to_avg <= circ_line_buffer((clb_read_idx)) & circ_line_buffer((clb_read_idx + 1 ))& circ_line_buffer((clb_read_idx -  1600)) &circ_line_buffer((clb_read_idx -1599));
                    if clb_read_idx = 2398 then
                       clb_read_idx <= 800;
                    else 
                       clb_read_idx <= clb_read_idx +2;
                    end if;                
                    
               elsif clb_read_idx >= 800 and clb_read_idx < 1601 then                  
                    o_pixel_data_to_avg <= circ_line_buffer((clb_read_idx)) & circ_line_buffer((clb_read_idx +1))& circ_line_buffer((clb_read_idx + 800)) &circ_line_buffer((clb_read_idx + 801));
                    if clb_read_idx = 1598 then
                       clb_read_idx <= 0;
                    else 
                       clb_read_idx <= clb_read_idx +2;
                    end if;                                    
                    
               end if;
                          
           else
               o_pixel_data_to_avg <= (others => '0');

           end if;
        end if;                                
    end process;              
end Behavioral;




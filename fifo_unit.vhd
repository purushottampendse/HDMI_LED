----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.07.2024 09:54:39
-- Design Name: 
-- Module Name: fifo_unit - Behavioral
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

entity fifo_unit is
Port (
    clk             : in std_logic;
    rst             : in std_logic;
    wr_en           : in std_logic;
    pixel_data_in   : in std_logic_vector(0 to 23);
    rd_en           : in std_logic;
    pixel_num       : in unsigned (8 downto 0);
    wr_done         : out std_logic;
    pixel_data_out  : out std_logic_vector(0 to 23);
    rd_done         : out std_logic
      );
end fifo_unit;

architecture Behavioral of fifo_unit is
    
    type state_type is ( IDLE, WRITE, READ);
    signal state , next_state : state_type;
    
    type array_type is array(0 to 255) of std_logic_vector(0 to 23);
    signal pixel_array : array_type := (0 to 255 => "000000000000000000000000");
    
    signal sig_write_done : std_logic :='0';
    signal sig_read_done  : std_logic := '0'; 
    signal sig_pixel_data_out : std_logic_vector(0 to 23) := "000000000000000000000000";
    
    signal write_index : unsigned( 8 downto 0);
    signal read_index  : unsigned (8 downto 0);
    
begin
    -- state transition logic
    SYNC_PROC: process ( clk,rst )
    begin
        if rising_edge(clk) then
            if rst = '0' then
                state <= IDLE;
            else
                state <= next_state;
            end if;
        end if;
    end process;

    NEXT_STATE_DECODE: process(state,clk,wr_en,rd_en)
    begin
        next_state <= state;
        case (state) is
        when IDLE =>
            if wr_en = '1' then
                next_state <= WRITE ;
            elsif rd_en = '1' then
                next_state <= READ ;
            else
                next_state <= IDLE;
            end if;
            
        when WRITE =>   
            if rd_en ='1' then
                next_state <= READ;
            else     
                next_state <= WRITE ;
            end if;
              
        when READ =>
            if rd_en = '0' then
                next_state <= IDLE;
            else
                next_state <= READ;
            end if;
        when others => next_state <= IDLE;
        
        end case;
    
    end process;
    
    OUTPUT_DECODE : process ( clk, rst )
    begin
        if rising_edge(clk) then
            if rst = '0' then
                sig_write_done <= '0' ;
                sig_pixel_data_out <= "000000000000000000000000";
            else
                if state = IDLE and next_state = WRITE then
                    write_index <= "000000000";
                elsif state = IDLE and  next_state = READ then
                    read_index <=  "000000000";
                
                elsif state = WRITE then
                    pixel_array(to_integer(write_index)) <= pixel_data_in;
                    if write_index = 255 then
                        sig_write_done <='1' ;                      
                    else
                        write_index <= write_index + 1;
                    end if;
                elsif state = READ then
                    sig_pixel_data_out <= pixel_array(to_integer(pixel_num));
                    if pixel_num =255 then                       
                        sig_read_done <= '1';
                    else
                        sig_read_done <= '0';                     
                    end if;
                    
                end if;
           end if;
        end if;                                       
    end process; 
    
    pixel_data_out <= sig_pixel_data_out;
    wr_done <= sig_write_done;
    rd_done <= sig_read_done;
                                                            
end Behavioral;

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.06.2024 08:57:07
-- Design Name: 
-- Module Name: signal_controller - Behavioral
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

entity signal_controller is
    Generic(
        bits_per_pixel : integer := 24;                         -- bits per pixel, rgb->24, rgbw->32
        one_high_time : integer := 80;                          -- interval of out signal high value for bit with value 1
        zero_high_time : integer := 40);                        -- interval of out signal high value for bit with value 0
    Port (
        clk : in STD_LOGIC;                                     -- clock, works with 100MHZ  
        rst : in STD_LOGIC;                                     -- reset linked to switch
        next_bit_en : in STD_LOGIC;                             -- signal from pixel controller to notify that signal for next bit should be generated
        pixel : in STD_LOGIC_VECTOR (0 to bits_per_pixel-1);    -- current pixel bits
        signal_out : out STD_LOGIC);
end signal_controller;

architecture Behavioral of signal_controller is
    constant position_limit : integer := bits_per_pixel - 1;    -- used to know when we reach final bit

    signal current_bit_position: integer := 0;
    signal signal_high_timer: integer := 0;                     -- timer value, which is set according to current bit

begin
    -- signal out logic
    SIGNAL_PROC: process ( clk, rst )
    begin
        if rising_edge(clk) then
            if rst = '0' then
                signal_out <= '0';
                signal_high_timer <= 0;
                current_bit_position <= 0;
            else
                -- default out is low
                signal_out <= '0';

                if signal_high_timer > 0 and next_bit_en = '0' then
                    -- for duration of timer, output is high
                    signal_out <= '1';
                    -- decrease timer value until we reach 0
                    signal_high_timer <= signal_high_timer - 1;

                elsif next_bit_en = '1' then
                    -- when next bit signal is received, we need to set timer to new value according to value of current bit
                    if pixel(current_bit_position) = '1' then
                        signal_high_timer <= one_high_time;
                    else
                        signal_high_timer <= zero_high_time;
                    end if;
                    
                    -- increase bit position (index)
                    current_bit_position <= current_bit_position + 1;
                    if current_bit_position = position_limit then
                        -- go back to 0 if we reached the end
                        current_bit_position <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
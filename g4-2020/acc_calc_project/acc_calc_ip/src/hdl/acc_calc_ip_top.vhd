----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/17/2020 08:38:23 PM
-- Design Name: 
-- Module Name: acc_calc_ip_top - Behavioral
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
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity acc_calc_ip_top is
  port (axis_aclk       : in  std_logic;
        axis_aresetn    : in  std_logic;
        m00_axis_tvalid : out std_logic;
        m00_axis_tready : in  std_logic;
        m00_axis_tlast  : out std_logic;
        m00_axis_tstrb  : out std_logic_vector(3 downto 0) := (others => '1');
        m00_axis_tdata  : out std_logic_vector(31 downto 0);
        s00_axis_tready : out std_logic;
        s00_axis_tvalid : in  std_logic;
        s00_axis_tlast  : in  std_logic;
        s00_axis_tdata  : in  std_logic_vector(31 downto 0));
end acc_calc_ip_top;

architecture Behavioral of acc_calc_ip_top is
  component acc_calc_ip is
    port (
      clk        : in  std_logic;
      areset     : in  std_logic;
      m_valid    : out std_logic;
      m_ready    : in  std_logic;
      m_last     : out std_logic;
      m_data_out : out std_logic_vector(31 downto 0);
      s_ready    : out std_logic;
      s_valid    : in  std_logic;
      s_last     : in  std_logic;
      s_data_in  : in  std_logic_vector(31 downto 0));
  end component acc_calc_ip;
begin
  acc_calc_inst: acc_calc_ip
    port map (
      clk        => axis_aclk,
      areset     => axis_aresetn,
      m_valid    => m00_axis_tvalid,
      m_ready    => m00_axis_tready,
      m_last     => m00_axis_tlast,
      m_data_out => m00_axis_tdata,
      s_ready    => s00_axis_tready,
      s_valid    => s00_axis_tvalid,
      s_last     => s00_axis_tlast,
      s_data_in  => s00_axis_tdata);

end Behavioral;

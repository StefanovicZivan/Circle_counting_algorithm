library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity acc_calc_ip_tb is
--  Port ( );
end acc_calc_ip_tb;

architecture Behavioral of acc_calc_ip_tb is

  signal s_data_in_s, m_data_out_s : std_logic_vector(31 downto 0);
  signal clk_s, areset_s, m_ready_s, m_valid_s, s_valid_s, s_ready_s, s_last_s, m_last_s  : std_logic;
  signal x, y : std_logic_vector(9 downto 0);
  
begin

  ee: entity work.acc_calc_ip(Behavioral)
  port map(
    clk => clk_s,
    s_data_in => s_data_in_s,
    m_data_out => m_data_out_s,
    areset => areset_s,
    m_ready => m_ready_s,
    s_ready => s_ready_s,
    m_valid => m_valid_s,
    s_valid => s_valid_s,
    s_last => s_last_s,
    m_last => m_last_s);
      
  clk_gen: process
  begin
    clk_s <= '0', '1' after 5 ns;
    wait for 10 ns;
  end process;
  
  stim_gen: process
  begin
    areset_s <= '0', '1' after 10ns;
    s_data_in_s <= "10000000000000000000000000000101", "00000000000000000001000000000100" after 25 ns, "00000000000000000010100000001010" after 35 ns;
    s_valid_s <= '1';
    m_ready_s <= '1', '0' after 1995ns, '1' after 2045ns;
    s_last_s <= '0', '1' after 50ns, '0' after 60ns;
    
  wait;
  end process;
  
  watch: process(m_data_out_s) is
  begin 
    x <= m_data_out_s(9 downto 0);
    y <= m_data_out_s(19 downto 10);
  end process;

end Behavioral;
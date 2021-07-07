library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--Package in which cosine and sine values are obtained
use work.pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity acc_calc_ip is
  port (clk   : in  std_logic;
        areset : in std_logic;
        --axi stream master interface for sending data to dma
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_last : out std_logic;
        m_data_out : out std_logic_vector(31 downto 0);
        --axi stream slave interface for reciving data from dma
        s_ready : out std_logic; 
        s_valid : in std_logic;
        s_last : in std_logic;
        s_data_in : in std_logic_vector(31 downto 0));           
end acc_calc_ip;

architecture Behavioral of acc_calc_ip is
  --Results of multiplying the radius r with the cosine and sine results
  signal r1_sin_res_s : signed(19 downto 0);
  signal r2_cos_res_s : signed(19 downto 0);

  --Non quantized signals
  signal a_nq_s : signed(19 downto 0);
  signal b_nq_s : signed(19 downto 0);

  --Quantized signals
  signal a_q_s : signed(9 downto 0);
  signal b_q_s : signed(9 downto 0);
  
  --a constant used to check if the data contains a radius value
  --constant RAD_PIX_MASK : std_logic_vector(31 downto 0 ) := "10000000000000000000000000000000"; 
  --a constant to check if the data is valid
  constant INVALID_PIX_MASK : std_logic_vector(31 downto 0 ) := "10000000000000000000000000000000"; 
  --it is used to check if the theta has reached 360
  constant full_circle : std_logic_vector(9 downto 0) := "0101100111";
  
  --Register signals
  type state_type is (mm2s, s2mm, idle);
  signal state_reg, state_next : state_type;                            --State register
  signal theta_reg, theta_next : std_logic_vector(9 downto 0);          --Angle manipulation register
  signal radius_reg, radius_next : std_logic_vector(9 downto 0);        --Radius storage register
  signal data_out_reg, data_out_next : std_logic_vector(31 downto 0);   --Out data storage register 
  signal address_reg, address_next : std_logic_vector(3 downto 0);      --Internal buffer addressing register
  signal valid_out_reg, valid_out_next : std_logic_vector(1 downto 0);  --Register used to offset _valid signals due to pipelining
  signal tlast_reg, tlast_next : std_logic;
  signal last_pulse_reg, last_pulse_next : std_logic;
  
  --Registers for storing results during arithmetic operations
  signal r1_reg, r1_next : std_logic_vector(19 downto 0); 
  signal r2_reg, r2_next : std_logic_vector(19 downto 0); 
  signal sin_reg, sin_next : std_logic_vector(9 downto 0); 
  signal cos_reg, cos_next : std_logic_vector(9 downto 0); 
  
  --Internal buffers to store the x and y positions of the pixels
  type reg_file_x is array (0 to 15) of std_logic_vector(9 downto 0);
  signal file_x_reg, file_x_next : reg_file_x;
  type reg_file_y is array (0 to 15) of std_logic_vector(9 downto 0);
  signal file_y_reg, file_y_next: reg_file_y;
  
  --Forming ROM memory using functions that store in a array samples of sin and cos
  constant sin_samples : arr_type(0 to 360) := init_sin_f; 
  constant cos_samples : arr_type(0 to 360) := init_cos_f; 
  
begin
  -- state and data registers 
  reg_process : process (clk, areset) is
  begin 
    if areset = '0' then              -- asynchronous reset (active low)
      state_reg <= idle;             
      theta_reg <= (others => '0');
      radius_reg <= (others => '0');
      address_reg <= (others => '0');
      r1_reg <= (others => '0');
      r2_reg <= (others => '0');
      sin_reg <= (others => '0');
      cos_reg <= (others => '0');
      valid_out_reg <= (others => '0');
      data_out_reg <= (others => '0');
      file_x_reg <= (others =>(others => '0'));
      file_y_reg <= (others =>(others => '0'));
      tlast_reg <= '0';
      last_pulse_reg <= '0';
    elsif clk'event and clk = '1' then  -- rising clock edge
      state_reg <= state_next;
      theta_reg <= theta_next;
      radius_reg <= radius_next;
      r1_reg <= r1_next;
      r2_reg <= r2_next;
      sin_reg <= sin_next;
      cos_reg <= cos_next;
      valid_out_reg <= valid_out_next;
      data_out_reg <= data_out_next;
      address_reg <= address_next;
      file_x_reg <= file_x_next;
      file_y_reg <= file_y_next;
      tlast_reg <= tlast_next;
      last_pulse_reg <= last_pulse_next;
    end if;
  end process reg_process;
  
  sequential_logic : process(m_ready, s_valid, state_reg, theta_reg, areset, s_last, address_reg, data_out_reg, valid_out_reg, 
                             r1_reg, r2_reg, tlast_reg, last_pulse_reg, s_data_in, radius_reg, r1_sin_res_s, r2_cos_res_s, b_q_s, a_q_s, file_x_reg, file_y_reg ) is
  begin
    -- default assignments
    state_next <= state_reg;
    theta_next <= theta_reg;
    radius_next <= radius_reg; 
    address_next <= address_reg;
    file_x_next <= file_x_reg;
    file_y_next <= file_y_reg;
    s_ready <= '0';
    m_valid <= '0';
    m_last <= '0';
    data_out_next <= data_out_reg;
    valid_out_next <= valid_out_reg;
    r1_next <= r1_reg;
    r2_next <= r2_reg;
    sin_next <= sin_reg;
    cos_next <= cos_reg;
    tlast_next <= tlast_reg;
    last_pulse_next <= last_pulse_reg;
    
    case state_reg is
      --a state entered after an asynchronous reset
      when idle =>
        if(areset = '1') then
          state_next <= mm2s;
        end if;
        
      --a state for recived data from RAM memory
      when mm2s =>
        s_ready <= '1';
        if(s_valid = '1') then
          --check if the data contains a radius value
          if(s_data_in(31) = '1') then
            radius_next <= s_data_in(9 downto 0);
          else
          --extracting x and y positions and placing in internal buffers
            file_x_next(to_integer(unsigned(address_reg))) <= s_data_in(9 downto 0);
            file_y_next(to_integer(unsigned(address_reg))) <= s_data_in(19 downto 10);
            --manipulation of the address register
            if((address_reg = "1111") or (s_last = '1')) then
              state_next <= s2mm;
              
              if(s_last = '1') then
                last_pulse_next <= '1';
              else
                last_pulse_next <= '0';
              end if;
            else
              address_next <= std_logic_vector(unsigned(address_reg) + 1); 
            end if; 
          end if;     
        end if;
        
      --state for calculating and sending data to the RAM memory
      when s2mm =>
        --timely activation of m_valid signal
        --promenio sam
        if(valid_out_reg = "11") then
          m_valid <= '1';
        end if;
        --manipulation of register wich indicates when the output becomes valid
        if(m_ready = '1') then 
          sin_next <= std_logic_vector(sin_samples(to_integer(unsigned(theta_reg))));
          cos_next <= std_logic_vector(cos_samples(to_integer(unsigned(theta_reg))));
          r1_next <= std_logic_vector(r1_sin_res_s);
          r2_next <= std_logic_vector(r2_cos_res_s);
          if(valid_out_reg < "11") then
            valid_out_next <= std_logic_vector(unsigned(valid_out_reg) + 1); 
          end if;
          --check if the positions in bounds, if not the data is marked as invalid
          if((a_nq_s < 0) or (b_nq_s < 0)) then
            data_out_next <= INVALID_PIX_MASK;
          else
            data_out_next <= std_logic_vector'("000000000000" & std_logic_vector(b_q_s) & std_logic_vector(a_q_s));         
          end if;
          --manipulation with angle
          if(theta_reg = full_circle) then
            theta_next <= (others => '0');
          else
            theta_next <= std_logic_vector(unsigned(theta_reg) + 1);
          end if; 
          --state change after all buffers data has been processed or new data from bafers has been processed
          if(theta_reg = "0000000010" and valid_out_reg = "11") then
            if(address_reg = "0000" and tlast_reg = '1') then
              state_next <= mm2s;
              theta_next <= (others => '0');
              valid_out_next <= (others => '0');
              tlast_next <= '0';
              
              if(last_pulse_reg = '1') then
                m_last <= '1';
              end if;
            end if;
          end if;

          if(theta_reg = "0000000001" and valid_out_reg = "11") then
            if(address_reg /= "0000") then
              address_next <= std_logic_vector(unsigned(address_reg) - 1);
            else
              tlast_next <= '1';
            end if;
          end if;
        end if; 
        
    end case;
  end process sequential_logic;
   
  --combinational logic
  r1_sin_res_s <= signed(radius_reg) * signed(cos_reg);
  r2_cos_res_s <= signed(radius_reg) * signed(sin_reg);
  
  a_nq_s <= signed(std_logic_vector'("0000" & file_x_reg(to_integer(unsigned(address_reg))) & "000000")) - signed(r1_reg);
  b_nq_s <= signed(std_logic_vector'("0000" & file_y_reg(to_integer(unsigned(address_reg))) & "000000")) - signed(r2_reg);
  
  m_data_out <= data_out_reg;
  
  --the process in which the results are quantized
  quantization_process : process (a_nq_s, b_nq_s) is
  begin  
    if (a_nq_s(5) = '1') then
      --the first digit behind the dot is 1
      a_q_s <= a_nq_s(15 downto 6) + 1;
    else
      a_q_s <= a_nq_s(15 downto 6);
    end if;

    if (b_nq_s(5) = '1') then
      --the first digit behind the dot is 1
      b_q_s <= b_nq_s(15 downto 6) + 1;
    else
      b_q_s <= b_nq_s(15 downto 6);
    end if;
  end process quantization_process;
end Behavioral;

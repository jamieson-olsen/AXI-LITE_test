-- dualram_axilite: a simple axi-lite example
-- map two single port block RAMs into the 32 bit AXI address space
-- each RAM is 2k x 32 bits, and must be read and written 32 bits at a time
--
-- the first word of RAM0 is BASE_ADDR + 0x0000
-- the next word of RAM0 is BASE_ADDR + 0x0004
-- the last word of RAM0 is BASE_ADDR + 0x1FFC
-- 
-- the first word of RAM1 is BASE_ADDR + 0x2000
-- the next word of RAM1 is BASE_ADDR + 0x2004
-- the last word of RAM1 is BASE_ADDR + 0x3FFC
--
-- So when adding this block into the Zynq/Kria design, choose the base address to be whatever
-- you want, and the total range should be: 2 x 2k x 4 bytes = 16k 
-- 
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity dualram_axilite is
	generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 32
	);
	port (
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0); -- 32 bits writes only
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
	);
end dualram_axilite;

architecture dualram_axilite_arch of dualram_axilite is

	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	signal rden, wren: std_logic;
	signal ram0_wea, ram1_wea: std_logic_vector(0 downto 0);
	signal aw_en: std_logic;
    signal ram0_douta, ram1_douta, ram_dout: std_logic_vector(31 downto 0);
    signal addra: std_logic_vector(10 downto 0);

    -- define the address range for each RAM relative to the BASE ADDRESS
    -- each RAM is 2k x 32 but since AXI address is BYTE BASED the BLOCKRAM address (11) bits 
    -- does not include the lower 2 bits of the AXI address
 
    constant RAM0_ADDR: std_logic_vector(31 downto 0) := "0000000000000000000-----------00";  -- 0x0000 - 0x1FFC
    constant RAM1_ADDR: std_logic_vector(31 downto 0) := "0000000000000000001-----------00";  -- 0x2000 - 0x3FFC

begin

	-- I/O Connections assignments

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	    <= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	    <= axi_rdata;
	S_AXI_RRESP	    <= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;

	-- Implement axi_awready generation
	-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	-- de-asserted when reset is low.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then

	        -- slave is ready to accept write address when
	        -- there is a valid write address and write data
	        -- on the write address and data bus. This design 
	        -- expects no outstanding transactions. 

	           axi_awready <= '1';
	           aw_en <= '0';
	        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
	           aw_en <= '1';
	           axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- Implement axi_awaddr latching
	-- This process is used to latch the address when both 
	-- S_AXI_AWVALID and S_AXI_WVALID are valid. 

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        -- Write Address latching
	        axi_awaddr <= S_AXI_AWADDR;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_wready generation
	-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	-- de-asserted when reset is low. 

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then

	          -- slave is ready to accept write data when 
	          -- there is a valid write address and write data
	          -- on the write address and data bus. This design 
	          -- expects no outstanding transactions.           

	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process; 

	-- Implement memory mapped register select and write logic generation
	-- The write data is accepted and written to memory mapped registers when
	-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	-- select byte enables of slave registers while writing.
	-- These registers are cleared when reset (active low) is applied.
	-- Slave register write enable is asserted when valid address and data are available
	-- and the slave is ready to accept the write address and write data.

	wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

	-- Implement write response logic generation
	-- The write response and response valid signals are asserted by the slave 
	-- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	-- This marks the acceptance of address and indicates the status of 
	-- write transaction.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00"; --need to work more on the responses
	    else
	      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then -- check if bready is asserted while bvalid is high)
	        axi_bvalid <= '0';                                 -- (there is a possibility that bready is always asserted high)
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arready generation
	-- axi_arready is asserted for one S_AXI_ACLK clock cycle when
	-- S_AXI_ARVALID is asserted. axi_awready is 
	-- de-asserted when reset (active low) is asserted. 
	-- The read address is also latched when S_AXI_ARVALID is 
	-- asserted. axi_araddr is reset to zero on reset assertion.

	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
	        -- indicates that the slave has acceped the valid read address
	        axi_arready <= '1';
	        -- Read Address latching 
	        axi_araddr  <= S_AXI_ARADDR;           
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arvalid generation
	-- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	-- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	-- data are available on the axi_rdata bus at this instance. The 
	-- assertion of axi_rvalid marks the validity of read data on the 
	-- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	-- is deasserted on reset (active low). axi_rresp and axi_rdata are 
	-- cleared to zero on reset (active low).
  
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
	        -- Valid read data is available at the read data bus
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; -- 'OKAY' response
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        -- Read data is accepted by the master
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;

	-- Implement memory mapped register select and read logic generation
	-- Slave register read enable is asserted when valid address is available
	-- and the slave is ready to accept the read address.

	rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

	-- Output register or memory read data
    -- When there is a valid read address (S_AXI_ARVALID) with 
    -- acceptance of read address by the slave (axi_arready), 
    -- output the read data, read address mux

	process( S_AXI_ACLK ) is
	begin
	  if (rising_edge (S_AXI_ACLK)) then
	    if ( S_AXI_ARESETN = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if ( rden='1' ) then
	          axi_rdata <= ram_dout;
	      end if;   
	    end if;
	  end if;
	end process;

-- memory map two 2kx32 RAMs into the AXI 32 bit address space
-- each RAM has a 11 bit address bus which connects 
-- to the lower 12 bits of the AXI address space BUT shifted by 2 bits due to AXI bytewide access

-- NOTE: we have TWO address pointers in AXI: a 32 bit write address pointer
-- (axi_awaddr) and a 32 bit read address pointer (axi_araddr). The issue here is that
-- our RAMs have only ONE address port (addra), so we need to switch between these two
-- address pointers depending on whether the AXI master is trying to write to the memory
-- or read from it. addra is 11 bits

addra <= axi_awaddr(12 downto 2) when (wren='1') else axi_araddr(12 downto 2);

-- now we need to map our 2k memory into the 32 bit address space, we'll do this manually.
-- the 11 blockram address lines will connect to the lower 12 bits of the 32 bit AXI address
-- space, which means that our RAMs will line up with 4k boundaries in the address space. BUT
-- we want our RAMs to ONLY appear ONCE in the address space, so we must decode the upper
-- bits of the address too, that's what the std_match is doing for us here. std_match ignores the
-- "----" don't care bits in the constants RAM0_ADDR and RAM1_ADDR

ram0_wea <= "1" when ( wren='1' and std_match(axi_awaddr, RAM0_ADDR) ) else "0";
ram1_wea <= "1" when ( wren='1' and std_match(axi_awaddr, RAM1_ADDR) ) else "0";

-- When the AXI master tries to read from this module choose which RAM to send back,
-- based on the address range, again we're using std_match to handle the don't care bits
-- in the address range definition for RAM0_ADDR and RAM1_ADDR

ram_dout <= ram0_douta when std_match(axi_araddr, RAM0_ADDR) else 
            ram1_douta when std_match(axi_araddr, RAM1_ADDR) else 
            (others=>'0');

-- xpm_memory_spram: Single Port RAM

ram0_inst : xpm_memory_spram
generic map (   
    ADDR_WIDTH_A => 11, -- 2048 address spaces 0x000-0x7FF
    AUTO_SLEEP_TIME => 0,
    BYTE_WRITE_WIDTH_A => 32,
    CASCADE_HEIGHT => 0,
    ECC_BIT_RANGE => "7:0",
    ECC_MODE => "no_ecc",
    ECC_TYPE => "none",
    -- IGNORE_INIT_SYNTH => 0,
    MEMORY_INIT_FILE => "none",
    MEMORY_INIT_PARAM => "0",
    MEMORY_OPTIMIZATION => "true",
    MEMORY_PRIMITIVE => "auto",
    MEMORY_SIZE => 2048,
    MESSAGE_CONTROL => 0,
    RAM_DECOMP => "auto",
    READ_DATA_WIDTH_A => 32,
    READ_LATENCY_A => 2,
    READ_RESET_VALUE_A => "0",
    RST_MODE_A => "SYNC",
    SIM_ASSERT_CHK => 0,
    USE_MEM_INIT => 1,
    USE_MEM_INIT_MMI => 0,
    WAKEUP_TIME => "disable_sleep",
    WRITE_DATA_WIDTH_A => 32,
    WRITE_MODE_A => "read_first",
    WRITE_PROTECT => 1)
port map (
    clka => S_AXI_ACLK,
    ena => '1',
    addra => addra,
    dina => S_AXI_WDATA,
    douta => ram0_douta,
    regcea => '1',
    rsta => '0',
    wea => ram0_wea,
    sleep => '0',
    sbiterra => open,
    dbiterra => open,
    injectdbiterra => '0',
    injectsbiterra => '0'
);

ram1_inst : xpm_memory_spram
generic map (   
    ADDR_WIDTH_A => 11, -- 2048 address spaces 0x000-0x7FF
    AUTO_SLEEP_TIME => 0,
    BYTE_WRITE_WIDTH_A => 32,
    CASCADE_HEIGHT => 0,
    ECC_BIT_RANGE => "7:0",
    ECC_MODE => "no_ecc",
    ECC_TYPE => "none",
    -- IGNORE_INIT_SYNTH => 0,
    MEMORY_INIT_FILE => "none",
    MEMORY_INIT_PARAM => "0",
    MEMORY_OPTIMIZATION => "true",
    MEMORY_PRIMITIVE => "auto",
    MEMORY_SIZE => 2048,
    MESSAGE_CONTROL => 0,
    RAM_DECOMP => "auto",
    READ_DATA_WIDTH_A => 32,
    READ_LATENCY_A => 2,
    READ_RESET_VALUE_A => "0",
    RST_MODE_A => "SYNC",
    SIM_ASSERT_CHK => 0,
    USE_MEM_INIT => 1,
    USE_MEM_INIT_MMI => 0,
    WAKEUP_TIME => "disable_sleep",
    WRITE_DATA_WIDTH_A => 32,
    WRITE_MODE_A => "read_first",
    WRITE_PROTECT => 1)
port map (
    clka => S_AXI_ACLK,
    ena => '1',
    addra => addra,
    dina => S_AXI_WDATA,
    douta => ram1_douta,
    regcea => '1',
    rsta => '0',
    wea => ram1_wea,
    sleep => '0',
    sbiterra => open,
    dbiterra => open,
    injectdbiterra => '0',
    injectsbiterra => '0'
);

end dualram_axilite_arch;

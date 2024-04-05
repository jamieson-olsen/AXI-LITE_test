library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dualram_axilite_testbench is
end dualram_axilite_testbench;

architecture dualram_axilite_testbench_arch of dualram_axilite_testbench is

component dualram_axilite
	generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 32
	);
	port (
		S_AXI_ACLK	    : in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	    : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	    : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0); -- 32 bits writes only
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	    : out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	    : out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
	);
end component;

-- master -> slave signals

signal clock: std_logic := '0';
signal reset_n: std_logic := '0';

signal AWADDR: std_logic_vector(31 downto 0) := (others=>'0');
signal AWPROT: std_logic_vector(2 downto 0) := (others=>'0');
signal AWVALID: std_logic := '0';

signal WDATA: std_logic_vector(31 downto 0) := (others=>'0');
signal WSTRB: std_logic_vector(3 downto 0) := (others=>'0');
signal WVALID: std_logic := '0';

signal BREADY: std_logic := '0';
signal ARADDR: std_logic_vector(31 downto 0) := (others=>'0');
signal ARPROT: std_logic_vector(2 downto 0) := (others=>'0');
signal ARVALID: std_logic := '0';
signal RREADY: std_logic := '0';

-- slave -> master signals

signal AWREADY: std_logic;
signal WREADY: std_logic;
signal BRESP: std_logic_vector(1 downto 0);
signal BVALID: std_logic;
signal ARREADY: std_logic;
signal RDATA: std_logic_vector(31 downto 0);
signal RRESP: std_logic_vector(1 downto 0);
signal RVALID: std_logic;

begin

reset_n <= '0', '1' after 80ns;

clock <= not clock after 5ns;  -- 100 MHz

aximasterproc: process
begin
    wait for 200ns;

    -- write to RAM0

    wait until rising_edge(clock);
    AWADDR <= X"80000000";  -- base + 0 
    AWVALID <= '1';
    WDATA <= X"DEADBEEF";
    WVALID <= '1';
    BREADY <= '1';
    WSTRB <= "1111";
    wait until (rising_edge(clock) and AWREADY='1' and WREADY='1');
    AWADDR <= X"00000000";
    AWVALID <= '0';
    WDATA <= X"00000000";
    AWVALID <= '0';
    WSTRB <= "0000";
    wait until (rising_edge(clock) and BVALID='1');
    BREADY <= '0';

    wait for 50ns;

    -- write to RAM1

    wait until rising_edge(clock);
    AWADDR <= X"80001008";
    AWVALID <= '1';
    WDATA <= X"CAFEBABE";
    WVALID <= '1';
    BREADY <= '1';
    WSTRB <= "1111";
    wait until (rising_edge(clock) and AWREADY='1' and WREADY='1');
    AWADDR <= X"00000000";
    AWVALID <= '0';
    WDATA <= X"00000000";
    AWVALID <= '0';
    WSTRB <= "0000";
    wait until (rising_edge(clock) and BVALID='1');
    BREADY <= '0';

    wait for 50ns;

    -- read from RAM0

    wait until rising_edge(clock);
    ARADDR <= X"80000000";  -- base + 0 
    ARVALID <= '1';
    RREADY <= '1';
    wait until (rising_edge(clock) and ARREADY='1');
    ARADDR <= X"00000000";
    ARVALID <= '0';
    wait until (rising_edge(clock) and RVALID='1');
    RREADY <= '0';

    wait for 50ns;

    -- read from RAM1

    wait until rising_edge(clock);
    ARADDR <= X"80001008";  -- base + 0 
    ARVALID <= '1';
    RREADY <= '1';
    wait until (rising_edge(clock) and ARREADY='1');
    ARADDR <= X"00000000";
    ARVALID <= '0';
    wait until (rising_edge(clock) and RVALID='1');
    RREADY <= '0';

    wait;
end process aximasterproc;

dut: dualram_axilite
	generic map( C_S_AXI_DATA_WIDTH => 32, C_S_AXI_ADDR_WIDTH => 32 )
	port map(
		S_AXI_ACLK => clock,
		S_AXI_ARESETN => reset_n,
		S_AXI_AWADDR => awaddr,
		S_AXI_AWPROT => awprot,
		S_AXI_AWVALID => awvalid,
		S_AXI_AWREADY => awready,
		S_AXI_WDATA => wdata,
		S_AXI_WSTRB => wstrb,
		S_AXI_WVALID => wvalid,
		S_AXI_WREADY => wready,
		S_AXI_BRESP => bresp,
		S_AXI_BVALID => bvalid,
		S_AXI_BREADY => bready,
		S_AXI_ARADDR => araddr,
		S_AXI_ARPROT => arprot,
		S_AXI_ARVALID => arvalid,
		S_AXI_ARREADY => arready,
		S_AXI_RDATA => rdata,
		S_AXI_RRESP => rresp,
		S_AXI_RVALID => rvalid,
		S_AXI_RREADY => rready
	);

end dualram_axilite_testbench_arch;

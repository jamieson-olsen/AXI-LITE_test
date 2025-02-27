a simple AXI-Lite peripheral which consists of two 1k x 32 BlockRAMs memory mapped into the AXI address space

	RAM0 = BASE+0x0000 through BASE+0xFFC
	RAM1 = BASE+0x1000 through BASE+0x1FFC

So when adding this module to a Zynq/Kria design, the base address must align with an 8k byte boundary
and the total memory size should be 8k (2 RAMs x 1k words/RAM x 4 bytes/word)

This module does not support byte level access. All reads and writes should be 32 bits.
Because AXI addressing is byte based, be sure to increment the address by 4, not 1, when reading
32 bit words. e.g. addr=0 is RAM0, word0; addr=4 is RAM0, word1, etc.

source file is dualram_axilite.vhd

this is based on the Vivado IP example design files, myip_v1_0*.vhd which are included here for reference.

testbench now works, handles a few simple AXI-LITE writes and reads it back. Two custom functions 
called axipeek and axipoke are provided to help readability. When running the testbench in the simulator
one just has to look at the console output and can read the report statements from axipeek and axipoke.

needed to add a wait state on the read handshaking logic to compensate for the additional 1 clock latency 
increase on blockram reads; this delays the ARREADY signal back to the master by 1 clock.

JTO




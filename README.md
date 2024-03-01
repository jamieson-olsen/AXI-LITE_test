a simple AXI-Lite peripheral which consists of two 2k x 32 BlockRAMs memory mapped into the AXI address space

	RAM0 = BASE+0x0000 through BASE+0x1FFC
	RAM1 = BASE+0x2000 through BASE+0x3FFC

So when adding this module to a Zynq/Kria design, choose the base address to be whatever you want, 
and the range should be 16k (2 RAMs x 2k words/RAM x 4 bytes/word)

This module does not support byte level access. All reads and writes should be 32 bits.

source file is dualram_axilite.vhd

this is based on the Vivado IP example design files, myip_v1_0*.vhd which are included here for reference.

JTO




`timescale 1ns / 1ps
/******************************************************************************
*                                                                             *
* RED TIN logic analyzer v0.1                                                 *
*                                                                             *
* Copyright (c) 2012 Andrew D. Zonenberg                                      *
* All rights reserved.                                                        *
*                                                                             *
* Redistribution and use in source and binary forms, with or without modifi-  *
* cation, are permitted provided that the following conditions are met:       *
*                                                                             *
*    * Redistributions of source code must retain the above copyright notice  *
*      this list of conditions and the following disclaimer.                  *
*                                                                             *
*    * Redistributions in binary form must reproduce the above copyright      *
*      notice, this list of conditions and the following disclaimer in the    *
*      documentation and/or other materials provided with the distribution.   *
*                                                                             *
*    * Neither the name of the author nor the names of any contributors may be*
*      used to endorse or promote products derived from this software without *
*      specific prior written permission.                                     *
*                                                                             *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED *
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF        *
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN     *
* NO EVENT SHALL THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT,         *
* INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT    *
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,   *
* DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY       *
* THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT         *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF    *
* THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.           *
*                                                                             *
******************************************************************************/

/**
	@file HardwareTestbench_RedTinLogicAnalyzer.v
	@author Andrew D. Zonenberg
	@brief Test module for the logic analyzer
 */
module HardwareTestbench_RedTinLogicAnalyzer(
	clk_20mhz, leds, buttons, uart_tx, uart_rx
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	input wire clk_20mhz;
	output reg[7:0] leds = 8'hF0;
	input wire[3:0] buttons;
	
	output wire uart_tx;
	input wire uart_rx;

	wire clk_20mhz_bufg;
	BUFG clkbuf(.I(clk_20mhz), .O(clk_20mhz_bufg));
	
	///////////////////////////////////////////////////////////////////////////////////////////////
	// Clock generation
	
	wire clk;
	wire clk_n;

	DCM_SP #(
		.CLKDV_DIVIDE(2.0),
		.CLKFX_DIVIDE(1),						//clk is 20 MHz * 4 = 80 MHz
		.CLKFX_MULTIPLY(4),
		.CLKIN_DIVIDE_BY_2("FALSE"),
		.CLKIN_PERIOD(50.0),
		.CLKOUT_PHASE_SHIFT("NONE"),
		.CLK_FEEDBACK("NONE"),
		.DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"),
		.DLL_FREQUENCY_MODE("LOW"),
		.DUTY_CYCLE_CORRECTION("TRUE"),
		.PHASE_SHIFT(0),
		.STARTUP_WAIT("TRUE")
	) clkmgr (
	//.CLK0(CLK0),
	//.CLK180(CLK180),
	//.CLK270(CLK270),
	//.CLK2X(CLK2X),
	//.CLK2X180(CLK2X180),
	//.CLK90(CLK90),
	//.CLKDV(CLKDV),
	.CLKFX(clk),
	.CLKFX180(clk_n),
	//.LOCKED(LOCKED),
	//.PSDONE(PSDONE),
	//.STATUS(STATUS),
	//.CLKFB(CLKFB),
	.CLKIN(clk_20mhz_bufg),
	.PSCLK(1'b0),
	.PSEN(1'b0),
	.PSINCDEC(1'b0),
	.RST(1'b0)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Dummy DUT
	reg[31:0] foobar = 0;
	always @(posedge clk) begin
		foobar <= foobar + 1;
	end
	
	//Move buttons into the main clock domain
	reg[3:0] buttons_buf = 0;
	always @(posedge clk) begin
		buttons_buf <= buttons;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The logic analyzer

	RedTinUARTWrapper analyzer (
		.clk(clk), 
		.din({
			/* {buttons_buf, 28'h0C0FFEE, foobar, 32'hfeedface, 32'hc0def00d} */
			buttons,
			124'h0
			}), 
		.uart_tx(uart_tx), 
		.uart_rx(uart_rx)
		);

endmodule

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
	output reg[7:0] leds = 0;
	input wire[3:0] buttons;
	
	output wire uart_tx;
	input wire uart_rx;

	wire clk;
	BUFG clkbuf(.I(clk_20mhz), .O(clk));
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Dummy DUT
	reg[31:0] foobar = 0;
	always @(posedge clk) begin
		foobar <= foobar + 1;
		leds <= 8'h55;
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
		.din({buttons_buf, 28'h0C0FFEE, foobar, 32'hfeedface, 32'hc0def00d}), 
		.uart_tx(uart_tx), 
		.uart_rx(uart_rx)
		);

endmodule

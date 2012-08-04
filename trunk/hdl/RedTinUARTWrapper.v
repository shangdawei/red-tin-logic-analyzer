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
	@file RedTinUARTWrapper.v
	@brief Wrapper for Red Tin LA plus a UART
 */
module RedTinUARTWrapper(clk, din, uart_tx, uart_rx);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	input wire clk;
	input wire[127:0] din;
	
	output wire uart_tx;
	input wire uart_rx;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual LA
	wire capture_done;
	reg la_reset = 0;
	reg[8:0] read_addr = 0;
	wire[127:0] read_data;
	
	reg[7:0] reconfig_din = 0;
	reg reconfig_ce = 0;
	
	RedTinLogicAnalyzer capture (
		.clk(clk), 
		.din(din), 
		.reconfig_din(reconfig_din), 
		.reconfig_ce(reconfig_ce), 
		.done(capture_done), 
		.reset(la_reset), 
		.read_addr(read_addr), 
		.read_data(read_data)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// UART 
	
	reg[15:0] uart_clkdiv = 16'd694;		//115.2 kbaud @ 80 MHz
	
	reg[7:0] uart_txdata = 8'hEE;
	reg uart_txen = 0;
	wire uart_txactive;
	wire uart_rxactive;
	wire uart_overflow;
	wire uart_rxrdy;
	wire[7:0] uart_rxout;
	UART uart (
		.clk(clk), 
		.clkdiv(uart_clkdiv),
		.tx(uart_tx), 
		.txin(uart_txdata), 
		.txrdy(uart_txen), 
		.txactive(uart_txactive), 
		.rx(uart_rx), 						//no RX logic for now, just tx
		.rxout(uart_rxout), 
		.rxrdy(uart_rxrdy), 
		.rxactive(uart_rxactive), 
		.overflow(uart_overflow)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive logic
	
	/*
		New packet structure:
		Magic number: 4 bytes, 0xFEEDFACE
		One dummy byte, 0x00
		256 bytes of data
	 */
	
	reg loading = 0;
	reg[31:0] magic = 0;
	reg[7:0] count = 0;
	
	always @(posedge clk) begin
	
		la_reset <= 0;
		reconfig_ce <= 0;
		reconfig_din <= 0;
	
		if(uart_rxrdy) begin
			
			//Actual loading of data
			if(loading) begin
				reconfig_ce <= 1;
				reconfig_din <= uart_rxout;
				count <= count + 8'h1;
				if(count == 8'hff) begin
					loading <= 0;
				end
			end
			
			//Wait for the magic number
			else begin
				
				//Magic number just arrived, we're reading the dummy byte now
				//Next clock data starts arriving
				if(magic == 32'hfeedface) begin
					loading <= 1;
					la_reset <= 1;
					magic <= 0;
					count <= 0;
				end
			
				//Read the next bytes of the magic number
				else begin
					magic <= {magic[23:0], uart_rxout};
				end
				
			end
			
		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit logic
	
	reg done_buf = 0;
	reg[3:0] bpos = 0;

	//Mux out the current byte from the output
	reg[7:0] current_byte = 0;
	always @(bpos, read_data) begin
		case(bpos)
			0: current_byte <= read_data[127:120];
			1: current_byte <= read_data[119:112];
			2: current_byte <= read_data[111:104];
			3: current_byte <= read_data[103:96];
			4: current_byte <= read_data[95:88];
			5: current_byte <= read_data[87:80];
			6: current_byte <= read_data[79:72];
			7: current_byte <= read_data[71:64];
			8: current_byte <= read_data[63:56];
			9: current_byte <= read_data[55:48];
			10: current_byte <= read_data[47:40];
			11: current_byte <= read_data[39:32];
			12: current_byte <= read_data[31:24];
			13: current_byte <= read_data[23:16];
			14: current_byte <= read_data[15:8];
			15: current_byte <= read_data[7:0];
		endcase
	end

	reg sending_sync_header = 0;

	always @(posedge clk) begin
		
		done_buf <= capture_done;
		uart_txen <= 0;
		
		if(capture_done) begin
		
			//Capture just finished! Start reading
			if(!done_buf) begin
				read_addr <= 0;
				bpos <= 0;
				sending_sync_header <= 1;
			end
			
			//If UART is busy, skip
			else if(uart_txen || uart_txactive) begin
				//nothing to do
			end

			//Send sync header
			else if(sending_sync_header) begin
				uart_txen <= 1;
				uart_txdata <= 8'h55;
				sending_sync_header <= 0;
			end			
			
			//Dumping data
			else begin
			
				//Dump this byte out the UART
				uart_txen <= 1;
				uart_txdata <= current_byte;
				bpos <= bpos + 4'h1;
				
				//If we're at the end of the byte, load the next word
				if(bpos == 15) begin
				
					bpos <= 0;
				
					//but if we're at the end of the buffer, stop
					if(read_addr == 511) begin
						read_addr <= 0;
					end
					
					else begin
						read_addr <= read_addr + 9'h1;
					end
				end
			
			end
			
		end
		
	end

endmodule

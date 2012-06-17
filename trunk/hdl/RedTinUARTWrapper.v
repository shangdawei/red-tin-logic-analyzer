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
module RedTinUARTWrapper(clk, din, uart_tx, uart_rx, leds);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	input wire clk;
	input wire[127:0] din;
	
	output wire uart_tx;
	input wire uart_rx;
	
	output reg[7:0] leds = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Trigger stuff
	reg[127:0] trigger_low = 0;
	reg[127:0] trigger_high = 0;
	reg[127:0] trigger_rising = 0;
	reg[127:0] trigger_falling = 0;
	reg[127:0] trigger_changing = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual LA
	wire capture_done;
	reg la_reset = 0;
	reg[8:0] read_addr = 0;
	wire[127:0] read_data;
	RedTinLogicAnalyzer capture (
		.clk(clk), 
		.din(din), 
		.trigger_low(trigger_low), 
		.trigger_high(trigger_high), 
		.trigger_rising(trigger_rising), 
		.trigger_falling(trigger_falling), 
		.trigger_changing(trigger_changing), 
		.done(capture_done), 
		.reset(la_reset), 
		.read_addr(read_addr), 
		.read_data(read_data), 
		.ext_trigger(1'b0)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// UART 
	
	reg[15:0] uart_clkdiv = 16'd40;	//500 kbaud @ 20 MHz
	
	reg[7:0] uart_txdata = 0;
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
		Packet structure:
			Sync header - 2 bytes, 0x55AA
			Opcode - 1 byte
			Length (of data) - 1 byte
			Data
	 */
	
	localparam OP_NULL					= 8'h00;
	localparam OP_TRIGGER_LOW			= 8'h01;
	localparam OP_TRIGGER_HIGH			= 8'h02;
	localparam OP_TRIGGER_FALLING		= 8'h03;
	localparam OP_TRIGGER_RISING		= 8'h04;
	localparam OP_TRIGGER_CHANGING	= 8'h05;
	localparam OP_RESET_LA				= 8'h06;
	
	localparam READ_STATE_IDLE			= 3'h0;		//waiting for first sync word
	localparam READ_STATE_SYNC1		= 3'h1;		//waiting for second sync word
	localparam READ_STATE_OPCODE		= 3'h2;		//waiting for opcode
	localparam READ_STATE_LENGTH		= 3'h3;		//waiting for data
	localparam READ_STATE_DATA			= 3'h4;		//reading data
	
	reg[2:0] read_state = READ_STATE_IDLE;
	reg[7:0] read_opcode = OP_NULL;
	reg[7:0] read_length = 0;
	
	always @(posedge clk) begin
	
		la_reset <= 0;
	
		if(uart_rxrdy) begin
			case(read_state)
			
				//Expect a 0x55, if not then we have a framing error so ignore it
				READ_STATE_IDLE: begin
					
					if(uart_rxout == 8'h55)
						read_state <= READ_STATE_SYNC1;
				end
				
				//Expect a 0xAA, if not then framing error
				READ_STATE_SYNC1: begin
				
					if(uart_rxout == 8'hAA)
						read_state <= READ_STATE_OPCODE;
					else
						read_state <= READ_STATE_IDLE;
				end
				
				//Read the opcode
				READ_STATE_OPCODE: begin
				
					read_opcode <= uart_rxout;
					read_state <= READ_STATE_LENGTH;
				end
				
				//Read the length
				READ_STATE_LENGTH: begin
				
					read_length <= uart_rxout;
					read_state <= READ_STATE_DATA;
					
					//Zero-length packets need special processing
					if(uart_rxout == 0) begin
						read_state <= READ_STATE_IDLE;
						
						//Process it now
						case(read_opcode)
							OP_RESET_LA: begin
								leds[0] <= 1;
								la_reset <= 1;
							end
							
							default: begin
							end
						endcase
					end
				end
				
				//Read the data 
				READ_STATE_DATA: begin
					leds[1] <= 1;
					
					//Read the data byte (into what depends on the opcode)
					//Triggers transmit high order byte first
					case(read_opcode)
						OP_TRIGGER_LOW: trigger_low <= {trigger_low[119:0], uart_rxout};
						OP_TRIGGER_HIGH: trigger_high <= {trigger_high[119:0], uart_rxout};
						OP_TRIGGER_RISING: trigger_rising <= {trigger_rising[119:0], uart_rxout};
						OP_TRIGGER_FALLING: trigger_falling <= {trigger_falling[119:0], uart_rxout};
						OP_TRIGGER_CHANGING: trigger_changing <= {trigger_changing[119:0], uart_rxout};
						default: begin
							
						end
					endcase
					
					read_length <= read_length - 1;
					
					//If we just read the last byte, stop
					if(read_length == 1) begin
						read_state <= READ_STATE_IDLE;
						leds[2] <= 1;
					end
				end
				
			endcase
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
			4: current_byte <= read_data[96:88];
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

	always @(posedge clk) begin
		
		done_buf <= capture_done;
		uart_txen <= 0;
		
		if(la_reset) begin
			leds[7] <= 0;
			leds[6] <= 0;
			leds[3] <= 0;
		end
		
		if(capture_done) begin
		
			leds[3] <= 1;
			
			//Capture just finished! Start reading
			if(!done_buf) begin
				read_addr <= 0;
				bpos <= 0;
			end
			
			//If UART is busy, skip
			else if(uart_txen || uart_txactive) begin
				//nothing to do
			end		
			
			//Dumping data
			else begin
				leds[6] <= 1;
			
				//Dump this byte out the UART
				uart_txen <= 1;
				uart_txdata <= current_byte;
				bpos <= bpos + 1;
				
				//If we're at the end of the byte, load the next word
				if(bpos == 15) begin
				
					bpos <= 0;
				
					//but if we're at the end of the buffer, stop
					if(read_addr == 511) begin
						read_addr <= 0;
						leds[7] <= 1;
					end
					
					else begin
						read_addr <= read_addr + 1;
					end
				end
			
			end
			
		end
		
	end

endmodule

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
	@file RedTinLogicAnalyzer.v
	@author Andrew D. Zonenberg
	@brief Top level module of the Red Tin logic analyzer
 */
module RedTinLogicAnalyzer(
	clk,
	din,
	trigger_low, trigger_high, trigger_rising, trigger_falling, trigger_changing,
	done, reset,
	read_addr, read_data,
	ext_trigger
    );
	 
	///////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations

	//Capture clock. Normally 1x or 2x the circuit clock.
	input wire clk;

	//Capture data. Up to 128 bits for now, may be wider later on.
	parameter DATA_WIDTH = 128;
	input wire[DATA_WIDTH-1:0] din;

	//Trigger masks. All conditions must be met in order to trigger.
	//A 1 bit means the condition must hold, a 0 bit means don't care.
	input wire[DATA_WIDTH-1:0] trigger_low;		//trigger if input is low
	input wire[DATA_WIDTH-1:0] trigger_high;		//trigger if input is high
	input wire[DATA_WIDTH-1:0] trigger_rising;	//trigger on rising edge of input
	input wire[DATA_WIDTH-1:0] trigger_falling;	//trigger on falling edge of input
	input wire[DATA_WIDTH-1:0] trigger_changing;	//trigger on any edge of input

	//The current system will capture 512 samples in a circular buffer starting 16 clocks
	//before the trigger condition holds.

	input wire[8:0] read_addr;
	output reg[DATA_WIDTH-1:0] read_data = 0;

	input wire reset;
	output wire done;
	
	input wire ext_trigger;

	///////////////////////////////////////////////////////////////////////////////////////////////
	// Trigger logic
	
	wire trigger;
	
	//Save the old value (used for edge detection)
	reg[DATA_WIDTH-1:0] din_buf = 0;
	reg[DATA_WIDTH-1:0] din_buf2 = 0;
	always @(posedge clk) begin
		din_buf <= din;
		din_buf2 <= din_buf;
	end
	
	//First, check which conditions hold
	wire[DATA_WIDTH-1:0] data_high;
	wire[DATA_WIDTH-1:0] data_low;
	wire[DATA_WIDTH-1:0] data_rising;
	wire[DATA_WIDTH-1:0] data_falling;
	wire[DATA_WIDTH-1:0] data_changing;
	assign data_high = din_buf;
	assign data_low = ~din_buf;
	assign data_rising = (din_buf & ~din_buf2);
	assign data_falling = (~din_buf & din_buf2);
	assign data_changing = (data_rising | data_falling);
	
	//Mask against the trigger.
	wire[DATA_WIDTH-1:0] data_high_masked;
	wire[DATA_WIDTH-1:0] data_low_masked;
	wire[DATA_WIDTH-1:0] data_rising_masked;
	wire[DATA_WIDTH-1:0] data_falling_masked;
	wire[DATA_WIDTH-1:0] data_changing_masked;
	assign data_high_masked = data_high & trigger_high;
	assign data_low_masked = data_low & trigger_low;
	assign data_rising_masked = data_rising & trigger_rising;
	assign data_falling_masked = data_falling & trigger_falling;
	assign data_changing_masked = data_changing & trigger_changing;
	
	//We trigger if the masked values equal the mask (all masked conditions hold)
	//or the external trigger is asserted.
	assign trigger =	(
							(data_high_masked == trigger_high) &&
							(data_low_masked == trigger_low) &&
							(data_rising_masked == trigger_rising) &&
							(data_falling_masked == trigger_falling) &&
							(data_changing_masked == trigger_changing)
							) || ext_trigger;

	///////////////////////////////////////////////////////////////////////////////////////////////
	// Capture logic
	
	//Current implementation is 128 wide (4x32) and 512 deep (4x 18k BRAM).
	//We need a 9-bit counter.
	
	//Fill the memory with garbage initially
	reg[DATA_WIDTH-1:0] capture_buf[511:0];
	reg[9:0] init_count;
	initial begin
		for(init_count = 0; init_count < 512; init_count = init_count + 1)
			capture_buf[init_count] = 128'hA3A3A3A3A3A3A3A3A3A3A3A3A3A3A3A3;
	end
	
	//Capture buffer is a circular ring buffer. Start at address X and end at X-1.
	//We are always capturing until triggered. Until the trigger signal is received
	//we increment the start and end addresses every clock and write to the 16th position
	//in the buffer; once triggered we stop incrementing them and record until the buffer
	//is full. From then until reset, capturing is halted and data can be dumped.
	reg[8:0] capture_start = 9'h000;
	reg[8:0] capture_end =   9'h1FF;
	reg[8:0] capture_waddr = 9'h010;
	
	//We're actually reading offsets in the circular buffer, not raw memory addresses.
	//Keep that in mind!
	wire[8:0] real_read_addr;
	assign real_read_addr = read_addr + capture_start;
	
	reg[1:0] state = 2'b11;	//00 = idle
									//01 = capturing
									//10 = done, wait for reset
									//11 = uninitialized, wait for reset
	assign done = (state == 2'b10);
	
	always @(posedge clk) begin
		
		//If in idle or capture state, write to the buffer
		//if(!state[1])
		//capture_buf[capture_waddr] <= din;
		//if(!state[1])
		//	capture_buf[capture_waddr] <= 128'h00c0ffeefeedfacedeadbeefbaadc0de;
		if(!state[1])
			capture_buf[capture_waddr] <= 128'h0;
		
		case(state)
			
			//Idle - capture data anyway so we can grab stuff before the trigger event
			//and then bump pointers
			2'b00: begin
				
				//If triggering, go on (but don't move window)
				if(trigger)
					state <= 2'b01;
					
				//otherwise move the window
				else begin
					capture_start <= capture_start + 9'h001;
					capture_end <= capture_end + 9'h001;
				end
				
				//In any case move our write address
				capture_waddr <= capture_waddr + 9'h001;
				
			end
			
			//Capturing - bump write pointer and stop if we're at the end, otherwise keep going
			2'b01: begin
				if(capture_waddr == capture_end)
					state <= 2'b10;
				else
					capture_waddr <= capture_waddr + 9'h001;
			end
			
			//Read stuff and wait for reset
			2'b10: begin
				//read_data <= capture_buf[real_read_addr];
				read_data <= 128'hdeadbeefbaadc0de01234567cdcdcdcd;
								
				if(reset) begin
					state <= 2'b00;
					
					capture_start <= 9'h000;
					capture_end <= 9'h1FF;
					capture_waddr <= 9'h010;
					
				end
			end
			
			2'b11: begin
				if(reset) begin
					state <= 2'b00;
					
					capture_start <= 9'h000;
					capture_end <= 9'h1FF;
					capture_waddr <= 9'h010;
					
				end
			end
			
		endcase
		
	end

endmodule

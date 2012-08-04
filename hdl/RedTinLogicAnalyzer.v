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
	
	reconfig_din, reconfig_ce,
	
	done, reset,
	read_addr, read_data
    );
	
	///////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations

	//Capture clock. Normally 1x or 2x the circuit clock.
	input wire clk;

	//Capture data. Up to 128 bits for now, may be wider later on.
	parameter DATA_WIDTH = 128;
	input wire[DATA_WIDTH-1:0] din;
	
	//Reconfiguration data for loading trigger settings
	input wire[7:0] reconfig_din;
	input wire reconfig_ce;

	//The current system will capture 512 samples in a circular buffer starting 16 clocks
	//before the trigger condition holds.

	input wire[8:0] read_addr;
	output reg[DATA_WIDTH-1:0] read_data = 0;

	input wire reset;
	output wire done;
	
	///////////////////////////////////////////////////////////////////////////////////////////////
	// Trigger logic
	
	wire trigger;
	
	//Save the old value (used for edge detection)
	//We buffer twice in order to ensure that we don't lengthen any critical paths.
	reg[DATA_WIDTH-1:0] din_buf = 0;
	reg[DATA_WIDTH-1:0] din_buf2 = 0;
	always @(posedge clk) begin
		din_buf <= din;
		din_buf2 <= din_buf;
	end
	
	/*
		128 channels packed into 64 LUTs (two bits for each).
		Configuration is done in eight columns of 8 LUTs (16 channels) each.
		
		Channels [0,1]....[14,15] are loaded at once, with one bit of data per clock.
		[16,17]...[30,31] are in the next row, etc.
		
		Only the low 16 bits of each LUT are meaningful; 16 "don't care" bytes must be clocked
		into the high half.
		
		In total the configuration bitstream is 256 bytes (256 bits per column).
		
		LUTs are loaded MSB first.
	 */
	wire[63:0] trigger_raw;
	wire[7:0] trigger_out_stage0;
	wire[7:0] trigger_out_stage1;
	wire[7:0] trigger_out_stage2;
	wire[7:0] trigger_out_stage3;
	wire[7:0] trigger_out_stage4;
	wire[7:0] trigger_out_stage5;
	wire[7:0] trigger_out_stage6;
	genvar ncol;
	generate
		for(ncol=0; ncol<8; ncol = ncol + 1) begin: triggerblock
		
			//channels [0,1]... [14,15]
			SRLC32E #(.INIT(32'h0)) trigger_0 (
				.Q(trigger_raw[ncol*8 + 0]),
				.Q31(trigger_out_stage0[ncol]),
				.A({1'b0, din_buf2[ncol*2 + 1], din_buf[ncol*2 + 1], din_buf2[ncol*2 + 0], din_buf[ncol*2 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(reconfig_din[ncol])
				);
				
			//channels [16,17]...[30,31]
			SRLC32E #(.INIT(32'h0)) trigger_1 (
				.Q(trigger_raw[ncol*8 + 1]),
				.Q31(trigger_out_stage1[ncol]),
				.A({1'b0, din_buf2[ncol*4 + 1], din_buf[ncol*4 + 1], din_buf2[ncol*4 + 0], din_buf[ncol*4 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage0[ncol])
				);
				
			SRLC32E #(.INIT(32'h0)) trigger_2 (
				.Q(trigger_raw[ncol*8 + 2]),
				.Q31(trigger_out_stage2[ncol]),
				.A({1'b0, din_buf2[ncol*6 + 1], din_buf[ncol*6 + 1], din_buf2[ncol*6 + 0], din_buf[ncol*6 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage1[ncol])
				);	
	
			SRLC32E #(.INIT(32'h0)) trigger_3 (
				.Q(trigger_raw[ncol*8 + 3]),
				.Q31(trigger_out_stage3[ncol]),
				.A({1'b0, din_buf2[ncol*8 + 1], din_buf[ncol*8 + 1], din_buf2[ncol*8 + 0], din_buf[ncol*8 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage2[ncol])
				);	

			SRLC32E #(.INIT(32'h0)) trigger_4 (
				.Q(trigger_raw[ncol*8 + 4]),
				.Q31(trigger_out_stage4[ncol]),
				.A({1'b0, din_buf2[ncol*10 + 1], din_buf[ncol*10 + 1], din_buf2[ncol*10 + 0], din_buf[ncol*10 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage3[ncol])
				);	
				
			SRLC32E #(.INIT(32'h0)) trigger_5 (
				.Q(trigger_raw[ncol*8 + 5]),
				.Q31(trigger_out_stage5[ncol]),
				.A({1'b0, din_buf2[ncol*12 + 1], din_buf[ncol*12 + 1], din_buf2[ncol*12 + 0], din_buf[ncol*12 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage4[ncol])
				);	

			SRLC32E #(.INIT(32'h0)) trigger_6 (
				.Q(trigger_raw[ncol*8 + 6]),
				.Q31(trigger_out_stage6[ncol]),
				.A({1'b0, din_buf2[ncol*14 + 1], din_buf[ncol*14 + 1], din_buf2[ncol*14 + 0], din_buf[ncol*14 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage5[ncol])
				);	
				
			SRLC32E #(.INIT(32'h0)) trigger_7 (
				.Q(trigger_raw[ncol*8 + 7]),
				//.Q31(trigger_out_stage7[ncol]),		//not used, end of the shift register
				.A({1'b0, din_buf2[ncol*16 + 1], din_buf[ncol*16 + 1], din_buf2[ncol*16 + 0], din_buf[ncol*16 + 0]}),
				.CE(reconfig_ce),
				.CLK(clk),
				.D(trigger_out_stage6[ncol])
				);
		end
	endgenerate
	
	//Keep track of position in the configuration bitstream and only enable the trigger
	//once configuration has completed
	reg config_done = 0;
	reg[7:0] config_count = 0;
	always @(posedge clk) begin
		if(reset) begin
			config_count <= 0;
			config_done <= 0;
		end
		
		else if(reconfig_ce) begin
			config_count <= config_count + 8'd1;
			if(config_count == 8'hFF)
				config_done <= 1;
		end
		
	end
	
	//Trigger if all channels' conditions were met and we're fully configured
	assign trigger = (trigger_raw == 64'h0) && config_done;

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
		if(!state[1])
			capture_buf[capture_waddr] <= din;
		
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
				read_data <= capture_buf[real_read_addr];
								
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

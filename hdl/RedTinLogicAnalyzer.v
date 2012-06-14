`timescale 1ns / 1ps
/**
	@file RedTinLogicAnalyzer.v
	@author Andrew D. Zonenberg
	@brief Top level module of the Red Tin logic analyzer
 */
module RedTinLogicAnalyzer(
	clk,
	din,
	trigger_low, trigger_high, trigger_rising, trigger_falling,
	done,
	read_addr, read_data
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

	//The current system will capture 512 samples in a circular buffer starting 16 clocks
	//before the trigger condition holds.

	input wire[8:0] read_addr;
	output reg[DATA_WIDTH-1:0] read_data = 0;
	
	output wire done;

	///////////////////////////////////////////////////////////////////////////////////////////////
	// Trigger logic
	
	wire trigger;
	
	//Save the old value (used for edge detection)
	reg[DATA_WIDTH-1:0] din_buf = 0;
	always @(posedge clk) begin
		din_buf <= din;
	end
	
	//First, check which conditions hold
	wire[DATA_WIDTH-1:0] data_high;
	wire[DATA_WIDTH-1:0] data_low;
	wire[DATA_WIDTH-1:0] data_rising;
	wire[DATA_WIDTH-1:0] data_falling;
	assign data_high = din;
	assign data_low = ~din;
	assign data_rising = (din & ~din_buf);
	assign data_falling = (~din & din_buf);
	
	//Mask against the trigger.
	wire[DATA_WIDTH-1:0] data_high_masked;
	wire[DATA_WIDTH-1:0] data_low_masked;
	wire[DATA_WIDTH-1:0] data_rising_masked;
	wire[DATA_WIDTH-1:0] data_falling_masked;
	assign data_high_masked = data_high & trigger_high;
	assign data_low_masked = data_low & trigger_low;
	assign data_rising_masked = data_rising & trigger_rising;
	assign data_falling_masked = data_falling & trigger_falling;
	
	//We trigger if the masked values equal the mask (all masked conditions hold).
	assign trigger =	(data_high_masked == trigger_high) &&
							(data_low_masked == trigger_low) &&
							(data_rising_masked == trigger_rising) &&
							(data_falling_masked == trigger_falling);
							
	///////////////////////////////////////////////////////////////////////////////////////////////
	// Capture logic
	
	//Current implementation is 128 wide (4x32) and 512 deep (4x 18k BRAM).
	//We need a 9-bit counter.
	
	//Fill the memory with zeroes initially
	reg[127:0] capture_buf[511:0];
	reg[9:0] init_count;
	initial begin
		for(init_count = 0; init_count < 512; init_count = init_count + 1)
			capture_buf[init_count] = 128'h0;
	end
	
	//Capture buffer is a circular ring buffer. Start at address X and end at X-1.
	//We are always capturing until triggered. Until the trigger signal is received
	//we increment the start and end addresses every clock and write to the 16th position
	//in the buffer; once triggered we stop incrementing them and record until the buffer
	//is full. From then until reset, capturing is halted and data can be dumped.
	reg[8:0] capture_start = 9'h000;
	reg[8:0] capture_end =   9'h1FF;
	reg[8:0] capture_waddr = 9'h010;
	
	reg[1:0] state = 0;	//00 = idle
								//01 = capturing
								//10 = wait for reset
								//11 = invalid
	assign done = state[1];
	always @(posedge clk) begin
		
		//If in idle or capture state, write to the buffer
		if(!state[0])
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
			
			//Read stuff
			//TODO: reset
			2'b10: begin
				read_data <= capture_buf[read_addr];
			end
			
		endcase
		
	end

endmodule

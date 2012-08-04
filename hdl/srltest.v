`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:38:36 08/03/2012 
// Design Name: 
// Module Name:    srltest 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module srltest(
    );

	////////////////////////////////////////////////////////////////////////////////////////////////
	//Clock generation
	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	reg clk = 0;
	always begin
		#5;
		clk = ready;
		#5;
		clk = 0;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////
	//Edge detection
	reg[1:0] old = 0;
	reg[1:0] current = 0;
	
	always @(posedge clk)
		old <= current;
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Test vectors
	reg[7:0] state = 0;
	always @(posedge clk) begin
		case(state)
			0: begin
				state <= 1;
			end
			
			1: begin
				current[0] <= 1;
				state <= 2;
			end
			
			2: begin
				current[1] <= 1;
				state <= 3;
			end
			
			3: begin
				current[0] <= 0;
				state <= 4;
			end
		endcase
	end

	////////////////////////////////////////////////////////////////////////////////////////////////
	//TODO: dynamic reprogramming
	reg din = 0;

	////////////////////////////////////////////////////////////////////////////////////////////////
	wire dout;
	SRLC32E #(
		.INIT({16'h0, 16'haaaa}) // Initial Value of Shift Register
	) SRL16E_inst (
		.Q(dout),
		//.Q31(Q31), // SRL cascade output pin
		.A({1'b0, old[1], current[1], old[0], current[0]}),
		.CE(1'b0),
      .CLK(clk),
      .D(din)
	);

endmodule

`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   21:24:26 06/13/2012
// Design Name:   HardwareTestbench_RedTinLogicAnalyzer
// Module Name:   /home/azonenberg/native/programming/redtin/hdl/testHardwareTestbench_RedTinLogicAnalyzer.v
// Project Name:  redtin
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: HardwareTestbench_RedTinLogicAnalyzer
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module testHardwareTestbench_RedTinLogicAnalyzer;

	// Inputs
	reg clk_20mhz = 0;
	reg [3:0] buttons = 0;
	reg uart_rx = 1;

	// Outputs
	wire [7:0] leds;
	wire uart_tx;

	// Instantiate the Unit Under Test (UUT)
	HardwareTestbench_RedTinLogicAnalyzer uut (
		.clk_20mhz(clk_20mhz), 
		.leds(leds), 
		.buttons(buttons),
		.uart_rx(uart_rx),
		.uart_tx(uart_tx)
	);

	reg ready = 0;
	initial begin
		#100;
      ready = 1;
		#5000;
		buttons[0] = 1;
	end
	
	always begin
		#25;
		clk_20mhz = ready;
		#25;
		clk_20mhz = 0;
	end
      
endmodule


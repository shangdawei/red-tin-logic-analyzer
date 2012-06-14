`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:31:40 06/13/2012 
// Design Name: 
// Module Name:    HardwareTestbench_RedTinLogicAnalyzer 
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
module HardwareTestbench_RedTinLogicAnalyzer(
	clk_20mhz, leds, buttons,
	read_addr, read_data
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	input wire clk_20mhz;
	output reg[7:0] leds = 0;
	input wire[3:0] buttons;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock multiplication
	
	wire clk;
	wire clk_2x;
	DCM_SP #(
		.CLKDV_DIVIDE(2.0),
		.CLKFX_DIVIDE(2),	
		.CLKFX_MULTIPLY(8),
		.CLKIN_DIVIDE_BY_2("FALSE"),
		.CLKIN_PERIOD(10.0),
		.CLKOUT_PHASE_SHIFT("NONE"),
		.CLK_FEEDBACK("2x"),
		.DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"),
		.DFS_FREQUENCY_MODE("LOW"),
		.DLL_FREQUENCY_MODE("LOW"),
		.DSS_MODE("NONE"),
		.DUTY_CYCLE_CORRECTION("TRUE"),
		.FACTORY_JF(16'hc080),
		.PHASE_SHIFT(0),
		.STARTUP_WAIT("TRUE")
	)
	clkmgr (
		.CLK0(clk),
		//.CLK180(CLK180),
		//.CLK270(CLK270),
		.CLK2X(clk_2x),
		//.CLK2X180(CLK2X180),
		//.CLK90(CLK90),
		//.CLKDV(CLKDV),
		//.CLKFX(clk),
		//.CLKFX180(CLKFX180),
		//.LOCKED(LOCKED),
		//.PSDONE(PSDONE),
		//.STATUS(STATUS),
		.CLKFB(clk_2x),
		.CLKIN(clk_20mhz),
		//.DSSEN(1'b0),
		//.PSCLK(PSCLK),
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
	
	//We can't actually capture the clock signal so make a fake one at the same frequency
	reg clk_fake = 0;
	always @(posedge clk_2x) begin
		clk_fake <= !clk_fake;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The logic analyzer

	input wire[8:0] read_addr;
	output wire[127:0] read_data;
	
	RedTinLogicAnalyzer analyzer (
		.clk(clk_2x), 
		.din({clk_fake, buttons, foobar, 91'h0}), 
		
		//Trigger when buttons[0] is pressed
		.trigger_low(128'h0), 
		.trigger_high(128'h0), 
		.trigger_rising({ 1'b0, 4'b0001, 32'h0, 91'h0 }), 
		.trigger_falling(128'h0), 
		
		//read data bus
		.read_addr(read_addr),
		.read_data(read_data)
		);

endmodule

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
	clk_20mhz, leds, buttons, uart_tx, uart_rx
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	input wire clk_20mhz;
	output reg[7:0] leds = 0;
	input wire[3:0] buttons;
	
	output wire uart_tx;
	input wire uart_rx;
	
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
	
	//Move buttons into the main clock domain
	reg[3:0] buttons_buf = 0;
	always @(posedge clk) begin
		buttons_buf <= buttons;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The logic analyzer

	reg[8:0] read_addr = 0;
	wire[127:0] read_data;
	
	wire done;
	reg reset = 0;
	
	RedTinLogicAnalyzer analyzer (
		.clk(clk_2x), 
		.din({clk_fake, buttons_buf, foobar, 91'h0}), 
		
		//Trigger when buttons[0] is pressed
		.trigger_low(128'h0), 
		.trigger_high(128'h0), 
		.trigger_rising({ 1'b0, 4'b0001, 32'h0, 91'h0 }), 
		.trigger_falling(128'h0), 
		
		//read data bus
		.done(done),
		.reset(reset),
		.read_addr(read_addr),
		.read_data(read_data)
		);
		
	always @(posedge clk) begin
		leds[0] <= done;
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// UART and glue to dump the capture buffer
	
	reg[15:0] uart_clkdiv = 16'd174;	//115200 baud @ 20 MHz
	//reg[15:0] uart_clkdiv = 16'd5;
	
	reg[7:0] uart_txdata = 0;
	reg uart_txen = 0;
	wire uart_txactive;
	wire uart_rxactive;
	wire uart_overflow;
	UART uart (
		.clk(clk), 
		.clkdiv(uart_clkdiv),
		.tx(uart_tx), 
		.txin(uart_txdata), 
		.txrdy(uart_txen), 
		.txactive(uart_txactive), 
		.rx(uart_rx), 						//no RX logic for now, just tx
		//.rxout(uart_rxout), 
		//.rxrdy(uart_rxrdy), 
		.rxactive(uart_rxactive), 
		.overflow(uart_overflow)
		);
	
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
		
		done_buf <= done;
		uart_txen <= 0;
		reset <= 0;
		
		if(done) begin
			
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
			
				//Dump this byte out the UART
				uart_txen <= 1;
				uart_txdata <= current_byte;
				bpos <= bpos + 1;
				
				//If we're at the end of the byte, load the next word
				if(bpos == 15) begin
				
					bpos <= 0;
				
					//but if we're at the end of the buffer, reset the capture module instead
					if(read_addr == 511) begin
						read_addr <= 0;
						reset <= 1;
						leds[1] <= 1;
					end
					
					else begin
						read_addr <= read_addr + 1;
					end
				end
			
			end
			
		end
		
	end

endmodule

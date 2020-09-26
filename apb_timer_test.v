`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   20:03:50 09/14/2020
// Design Name:   apb_pwm
// Module Name:   D:/ISE_labs/apb_timer/apb_timer_test.v
// Project Name:  apb_timer
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: apb_pwm
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module apb_timer_test;

	// Inputs
	reg PCLK;
	reg PRESETn;
	reg PSEL;
	reg [11:2] PADDR;
	reg PENABLE;
	reg PWRITE;
	reg [31:0] PWDATA;
	reg EXTIN;

	// Outputs
	wire [31:0] PRDATA;
	wire PREADY;
	wire PSLVERR;
	wire TIMEROUT;
	wire TIMERINT;
	
	parameter cycle = 20;
	always #(0.5*cycle) PCLK  = ~PCLK;
	always # cycle      EXTIN = ~EXTIN;
	// Instantiate the Unit Under Test (UUT)
	apb_pwm uut (
		.PCLK(PCLK), 
		.PRESETn(PRESETn), 
		.PSEL(PSEL), 
		.PADDR(PADDR), 
		.PENABLE(PENABLE), 
		.PWRITE(PWRITE), 
		.PWDATA(PWDATA), 
		.PRDATA(PRDATA), 
		.PREADY(PREADY), 
		.PSLVERR(PSLVERR), 
		.EXTIN(EXTIN), 
		.TIMEROUT(TIMEROUT), 
		.TIMERINT(TIMERINT)
	);

	initial begin
		// Initialize Inputs
		PCLK = 0;
		PRESETn = 0;
		PSEL = 0;
		PADDR = 0;
		PENABLE = 0;
		PWRITE = 0;
		PWDATA = 0;
		EXTIN = 0;
	
		#(3.6 * cycle) PRESETn = 1;

	
		#cycle		write_byte1(10'd1,32'd9);	//Current Value0
		#cycle		write_byte1(10'd2,32'd9);	//Reload  Value0
			
		#cycle		write_byte1(10'd3,32'd19);	//Current Value1
		#cycle		write_byte1(10'd4,32'd19);	//Reload  Value1
		
		#cycle		write_byte1(10'd0,32'h29);  	//Ctrl reg     (pulse)	
		#(5000*cycle);		
		
		#cycle		write_byte1(10'd0,32'h0);  	//Ctrl reg 		
		#(50*cycle);
		#cycle		write_byte1(10'd0,32'h37);  	//Ctrl reg     (pwm)
		#(5000*cycle);
				
		#cycle		write_byte1(10'd0,32'h0);  	//Ctrl reg 		
		#(50*cycle);
		#cycle		write_byte1(10'd0,32'h11);  	//Ctrl reg     (single)
		
		// Wait 100 ns for global reset to finish
		#(5000*cycle);
		$finish;
        
		// Add stimulus here

	end
	task write_byte1;
		input	[9:0]	addr;
		input	[31:0]	data_in;
		begin
			@(negedge PCLK);
			PADDR = addr;
			PWDATA = data_in;
			PSEL = 1;
			PWRITE = 1;
			
			@(negedge PCLK);
			PENABLE = 1;
			#( cycle);
			PADDR = 0;
			PWDATA = 0;
			PSEL = 0;
			PWRITE = 0;
			PENABLE = 0;
			
		end
	endtask
	
	task read_byte1;
		input	[9:0]	addr;
		begin
			@(negedge PCLK);
			PADDR = addr;
			PSEL = 1;			
			
			@(negedge PCLK);
			PENABLE = 1;			
			#( cycle);
			PADDR = 0;
			PSEL = 0;
			PENABLE = 0;
		end
	endtask		      
endmodule


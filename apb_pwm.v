`timescale 1ns / 1ps
//------------------------------------------------------------------------------
//  Version and Release Control Information:
//
//  File Revision       : $ Revision: 1.0     $
//  File Date           : $ Date: 2020-09-26  $
//  File name:          : $ apb_pwm.v         $                                       
//  Author              : $ Guojia            $
//  Contact information : $ 739819100@qq.com  $
// 
//------------------------------------------------------------------------------
// Verilog-2001 (IEEE Std 1364-2001)
//------------------------------------------------------------------------------
// Description:
//
//                                 _________________
// _______________________________/		     \_________________	
//	state=idle  |  state=sta_low	state=sta_hig        state=sta_low
//      <Enable=0>  |			 Enable=1 
//------------------------------------------------------------------------------
// Abstract : APB PWM TIMER
//------------------------------------------------------------------------------
// 0x00 RW    CTRL[5:0]
//			  [5:4] Mode  (00idle,01pulse,10flip,11pwm)
//              [3] Timer Interrupt Enable
//              [2] Select External input as Clock£,Textin >= 2 * Tpclk
//              [1] Select External input as Enable
//              [0] Enable
// 0x04 RW    Current Value0[31:0]
// 0x08 RW    Reload  Value0[31:0]
// 0x0c RW    Current Value1[31:0]
// 0x10 RW    Reload  Value1[31:0]
// 0x14 R/Wc  Timer Interrupt
//              [0] Interrupt, wright 1 to clear

module apb_pwm (
  input  wire        PCLK,    // PCLK for timer operation
  input  wire        PRESETn, // Reset

  input  wire        PSEL,    // Device select
  input  wire [11:2] PADDR,   // Address
  input  wire        PENABLE, // Transfer control
  input  wire        PWRITE,  // Write control
  input  wire [31:0] PWDATA,  // Write data
  

  output wire [31:0] PRDATA,  // Read data
  output wire        PREADY,  // Device ready
  output wire        PSLVERR, // Device error response

  input  wire        EXTIN,   // External input£¬Textin >= Tpclk

  output wire        TIMEROUT,  // Timer output
  output wire        TIMERINT); // Timer interrupt output 
  
 // Signals for read/write controls
wire          read_enable;
wire          write_enable;
wire          write_enable00; // Write enable for Control register
wire          write_enable04; // Write enable for Current Value0 register
wire          write_enable08; // Write enable for Reload  Value0 register
wire          write_enable0c; // Write enable for Current Value1 register
wire          write_enable10; // Write enable for Reload  Value1 register
wire          write_enable14; // Write enable for Interrupt register
reg    [31:0] read_mux_byte0;
reg    [31:0] read_mux_byte0_reg;
reg    [31:0] read_mux_word; 
  
// Signals for Control registers
reg     [5:0] reg_ctrl;
reg    [31:0] reg_curr_val0;
reg    [31:0] reg_curr_val1;
reg    [31:0] nxt_curr_val0;
reg    [31:0] nxt_curr_val1;
reg    [31:0] reg_reload_val0;
reg    [31:0] reg_reload_val1;

// State machine
reg           idle;	    // Timer Not Enable	
reg           sta_low;	// 
reg           sta_hig;	//

wire		  go_idle;
wire		  go_low;
wire		  go_hig;

reg	   [31:0] sta_hig_next_val;  // Next current Value register of sta_hig
reg	   [31:0] sta_hig_curr_val;  // Current Value register of sta_hig
wire     [31:0] hig_reload_val;    // Reload  Value wire     of sta_gih

// Internal signals
reg           ext_in_sync1;  // Synchronisation registers for external input
reg           ext_in_sync2;  // Synchronisation registers for external input
reg           ext_in_delay;  // Delay register for edge detection
wire          ext_in_enable; // enable control for external input
wire          dec_ctrl;      // Decrement  control
wire          clk_ctrl;      // Clk select result
wire          enable_ctrl;   // Enable select result
wire          edge_detect;   // Edge detection
reg           reg_timer_int; // Timer interrupt output register
wire          timer_int_clear; // Clear timer interrupt status
wire          timer_int_set;   // Set timer interrupt status
wire          update_timer_int;// Update Timer interrupt output register

// Start of main code
// Read and write control signals
assign  read_enable  = PSEL & (~PWRITE); // assert for whole APB read transfer
assign  write_enable = PSEL & (~PENABLE) & PWRITE; // assert for 1st cycle of write transfer
assign  write_enable00 = write_enable & (PADDR[11:2] == 10'h000);
assign  write_enable04 = write_enable & (PADDR[11:2] == 10'h001);
assign  write_enable08 = write_enable & (PADDR[11:2] == 10'h002);
assign  write_enable0c = write_enable & (PADDR[11:2] == 10'h003);
assign  write_enable10 = write_enable & (PADDR[11:2] == 10'h004);
assign  write_enable14 = write_enable & (PADDR[11:2] == 10'h005);

// Write operations
  // Control register
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      reg_ctrl <= {6{1'b0}};
    else if (write_enable00)
      reg_ctrl <= PWDATA[5:0];
  end

  // Current Value register0
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      reg_curr_val0 <= {32{1'b0}};
    else if(dec_ctrl)
      reg_curr_val0 <= nxt_curr_val0;
  end

  // Reload Value register0
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      reg_reload_val0 <= {32{1'b0}};
    else if (write_enable08)
      reg_reload_val0 <= PWDATA[31:0];
  end
  
   // Current Value register1
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      reg_curr_val1 <= {32{1'b0}};
    else if (write_enable0c | dec_ctrl)
      reg_curr_val1 <= nxt_curr_val1;
  end

  // Reload Value register1
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      reg_reload_val1 <= {32{1'b0}};
    else if (write_enable10)
      reg_reload_val1 <= PWDATA[31:0];
  end 
 
  // lower 8 bits -registered. Current value register mux not done here
  // because the value can change every cycle
/* always @(PADDR or reg_ctrl or reg_reload_val0  or reg_reload_val1 or
   reg_timer_int) */
   always @(*)
  begin
   if (PADDR[11:5] == 8'h00) begin
     case (PADDR[4:2])
     3'h0: read_mux_byte0 =  {{26{1'b0}}, reg_ctrl};
     3'h1: read_mux_byte0 =   {32{1'b0}};
     3'h2: read_mux_byte0 =  reg_reload_val0[31:0];
	 3'h3: read_mux_byte0 =   {32{1'b0}}; 
	 3'h4: read_mux_byte0 =  reg_reload_val1[31:0];
     3'h5: read_mux_byte0 =  {{31{1'b0}}, reg_timer_int};
     default:  read_mux_byte0 =   {32{1'bx}}; // x propagation
     endcase
   end
    else begin
      read_mux_byte0 =   {32{1'b0}};     //default read out value
    end
  end

  // Register read data
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      read_mux_byte0_reg <= {32{1'b0}};
    else if (read_enable)
      read_mux_byte0_reg <= read_mux_byte0;
  end

  // Second level of read mux
/*   always @(PADDR or read_mux_byte0_reg or reg_curr_val0 or reg_reload_val0 or
     reg_curr_val0 or reg_reload_val0) */
	 always@(*)
  begin
  if (PADDR[11:5] == 8'h00) begin
    case (PADDR[4:2])
	  3'b000:  read_mux_word = read_mux_byte0_reg;
      3'b001:  read_mux_word = reg_curr_val0[31:0];
      3'b010:  read_mux_word = read_mux_byte0_reg;
      3'b011:  read_mux_word = sta_hig_curr_val[31:0];
      3'b100:  read_mux_word = read_mux_byte0_reg;	  
      3'b101:  read_mux_word = read_mux_byte0_reg;
      default : read_mux_word = {32{1'bx}};
    endcase
  end
  else begin
    read_mux_word = read_mux_byte0_reg;
  end
  end


 
  
  // Output read data to APB
  assign PRDATA = (read_enable) ? read_mux_word : {32{1'b0}};
  assign PREADY  = 1'b1; // Always ready
  assign PSLVERR = 1'b0; // Always okay  
  
  assign ext_in_enable = reg_ctrl[1] | reg_ctrl[2] | PSEL;

  // Synchronize input and delay for edge detection
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      begin
      ext_in_sync1 <= 1'b0;
      ext_in_sync2 <= 1'b0;
      ext_in_delay <= 1'b0;
      end
    else if (ext_in_enable)
      begin
      ext_in_sync1 <= EXTIN;
      ext_in_sync2 <= ext_in_sync1;
      ext_in_delay <= ext_in_sync2;
      end
  end  
  
   // Edge detection
  assign edge_detect = ext_in_sync2 & (~ext_in_delay);

  // Clock selection
  assign clk_ctrl    = reg_ctrl[2] ? edge_detect : 1'b1;

  // Enable selection
  assign enable_ctrl = reg_ctrl[1] ? ext_in_sync2 : 1'b1;

  // Overall decrement control
  assign dec_ctrl    = reg_ctrl[0] & enable_ctrl & clk_ctrl; 
  
  // Decrement counter
/*   always @(write_enable04 or PWDATA or dec_ctrl or reg_curr_val0 or
  reg_reload_val0 or sta_low) */
  always @(*)
  begin
  if (write_enable04)
    nxt_curr_val0 = PWDATA[31:0]; // Software write to timer
  else if(go_low)
    nxt_curr_val0 = reg_reload_val0;
  else if (dec_ctrl & sta_low)
    begin
    if (reg_curr_val0 == {32{1'b0}})
      nxt_curr_val0 = reg_reload_val0; // Reload
    else
      nxt_curr_val0 = reg_curr_val0 - 1'b1; // Decrement
    end
  else
    nxt_curr_val0 = nxt_curr_val0; // Unchanged
  end

  // Decrement counter
/*  always @(write_enable10 or PWDATA or dec_ctrl or reg_curr_val1 or
  reg_reload_val1 or sta_hig)*/
  always @(*)
  begin
  if (write_enable10)
    nxt_curr_val1 = PWDATA[31:0]; // Software write to timer
  else if (dec_ctrl & sta_hig & (reg_ctrl[5:4] == 2'b01))
    begin
    if (reg_curr_val1 == {32{1'b0}})
      nxt_curr_val1 = reg_reload_val1; // Reload
    else
      nxt_curr_val1 = reg_curr_val1 - 1'b1; // Decrement
    end
  else
    nxt_curr_val1 = reg_curr_val1; // Unchanged
  end  
 
	    
   // Reload Value register of sta_hig
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      sta_hig_curr_val <= {32{1'b0}};
	else if(dec_ctrl)
	    sta_hig_curr_val <= sta_hig_next_val;
  end 
   
assign hig_reload_val = (reg_ctrl[5:4] == 2'b11 ? reg_reload_val1 :
	                     (reg_ctrl[5:4] == 2'b10 ? reg_reload_val0 :
                        (reg_ctrl[5:4] == 2'b01 ? 32'b1  :32'b0		))); 

  // Sta_high decrement counter
  always @(*)
  begin
	if(go_hig)
	  sta_hig_next_val = hig_reload_val;
	else if (dec_ctrl & sta_hig)
      begin
        if (sta_hig_curr_val == {32{1'b0}})
          sta_hig_next_val = hig_reload_val; // Reload
        else
          sta_hig_next_val = sta_hig_curr_val - 1'b1; // Decrement
      end
    else
      sta_hig_next_val = sta_hig_next_val; // Unchanged
  end  
 
 
 
  always @(posedge PCLK or negedge PRESETn) begin
	if (!PRESETn)
		idle = 1'b0;
	else if(go_idle)
		idle = 1'b1;
	else if(go_low)
		idle = 1'b0;		
  end
	
  always @(posedge PCLK or negedge PRESETn) begin 
	if(!PRESETn)
		sta_low <= 1'b0;
	else if (go_low)
		sta_low <= 1'b1;
	else if (go_hig | go_idle)
		sta_low <= 1'b0;
  end

  always @(posedge PCLK or negedge PRESETn) begin 
	if (!PRESETn)
		sta_hig <= 1'b0;
	else if (go_hig)
		sta_hig <= 1'b1;
	else if (go_idle | go_low)
		sta_hig <= 1'b0;
  end 
  
  assign go_idle =  (  ((!reg_ctrl[0]) & (sta_hig | sta_low)) | ((!(|reg_ctrl[5:4])) & ((sta_hig | sta_low)))   & (!idle)  );
//  assign go_low  =  (write_enable00 & PWDATA[0] & (|PWDATA[5:4])) | (sta_hig & reg_ctrl[0] & (|reg_ctrl[5:4]) & (sta_hig_curr_val==32'h00000000));
  assign go_low  =  (write_enable00 & PWDATA[0] & (|PWDATA[5:4])) | (sta_hig & reg_ctrl[0] & (|reg_ctrl[5:4]) & (sta_hig_curr_val==32'h00000001));
  assign go_hig  =   sta_low & reg_ctrl[0] & (|reg_ctrl[5:4]) & (reg_curr_val0==32'h00000001);
  
  
  
  // Interrupt generation
  // Trigger an interrupt when decrement to 0 and interrupt enabled
  // and hold it until clear by software
//  assign timer_int_set   = (dec_ctrl & reg_ctrl[3] & sta_hig & (reg_curr_val1==32'h00000001));
  assign timer_int_set   = (dec_ctrl & reg_ctrl[3] & sta_hig & (sta_hig_curr_val==32'h00000001));
  assign timer_int_clear = write_enable14 & PWDATA[0];
  assign update_timer_int= timer_int_set | timer_int_clear;

  // Registering interrupt output
  always @(posedge PCLK or negedge PRESETn)
  begin
    if (~PRESETn)
      reg_timer_int <= 1'b0;
    else if (update_timer_int)
      reg_timer_int <= timer_int_set;
  end

  // Connect to external
  assign TIMERINT = reg_timer_int;  
  assign TIMEROUT = sta_hig ? 1'b1 : 1'b0;
  
endmodule

//------------------------------------------------------------------------------
//  Version and Release Control Information:
//
//  File Revision        : $ Revision: 1.0  		 $
//  File Date            : $ Date: 2020-09-26 	 $
//  File name            : $ apb_pwm.v        	 $                                       
//  Author               : $ Guojia          		 $
//  Contact information	 : $ 739819100@qq.com 	 $
// 
//------------------------------------------------------------------------------
// Verilog-2001 (IEEE Std 1364-2001)
//------------------------------------------------------------------------------
// Description:
//
//                                        _________________
// ______________________________________/		             \_________________	
//	state=idle  |  state=sta_low	         state=sta_hig        state=sta_low
//  <Enable=0>  |		                         Enable=1 
//------------------------------------------------------------------------------
// Abstract : APB PWM TIMER
//------------------------------------------------------------------------------
// 0x00 RW    CTRL[5:0]
//	          [5:4] Mode  (00idle,01pulse,10flip,11pwm)
//              [3] Timer Interrupt Enable
//              [2] Select External input as Clock，Textin >= Tpclk
//              [1] Select External input as Enable
//              [0] Enable
// 0x04 RW    Current Value0[31:0]
// 0x08 RW    Reload  Value0[31:0]
// 0x0c RW    Current Value1[31:0]
// 0x10 RW    Reload  Value1[31:0]
// 0x14 R/Wc  Timer Interrupt
//              [0] Interrupt, wright 1 to clear

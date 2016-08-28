//////////////////////////////////////////////////////////////////////////////
//
//  Xilinx, Inc. 2007                 www.xilinx.com
//
//  XAPP xxx
//
//////////////////////////////////////////////////////////////////////////////
//
//  File name :       dcminit.v
//
//  Description :     DCM Initialization/Reset Logic
//                    The purpose of this module is to properly handle the
//                    DCM reset. DVI clock is transmitted through a cable
//                    which can be plugged in and out at any time. The
//                    DCM needs to be reset accordingly in order to re-gain
//                    the lock. There are also cases the DCM may lose its
//                    lock during video timing switch.
//
//  Author :          Bob Feng
//
//  Disclaimer: LIMITED WARRANTY AND DISCLAMER. These designs are
//              provided to you "as is". Xilinx and its licensors makeand you
//              receive no warranties or conditions, express, implied,
//              statutory or otherwise, and Xilinx specificallydisclaims any
//              implied warranties of merchantability, non-infringement,or
//              fitness for a particular purpose. Xilinx does notwarrant that
//              the functions contained in these designs will meet your
//              requirements, or that the operation of these designswill be
//              uninterrupted or error free, or that defects in theDesigns
//              will be corrected. Furthermore, Xilinx does not warrantor
//              make any representations regarding use or the results ofthe
//              use of the designs in terms of correctness, accuracy,
//              reliability, or otherwise.
//
//              LIMITATION OF LIABILITY. In no event will Xilinx or its
//              licensors be liable for any loss of data, lost profits,cost
//              or procurement of substitute goods or services, or forany
//              special, incidental, consequential, or indirect damages
//              arising from the use or operation of the designs or
//              accompanying documentation, however caused and on anytheory
//              of liability. This limitation will apply even if Xilinx
//              has been advised of the possibility of such damage. This
//              limitation shall apply not-withstanding the failure ofthe
//              essential purpose of any limited remedies herein.
//
//  Copyright © 2004 Xilinx, Inc.
//  All rights reserved
//
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ns / 1ps

module dcminit (
  input  wire stbclk, // a stable clock source that never disappears
  input  wire dcmlck,
  input  wire dcmclkin_st, //dcm clkin status: 0 - toggle; 1 - not toggle
  output reg dcmrst = 1'b0
);

  //Determine the readiness of clocks
  wire clkrdy;
  assign clkrdy = dcmlck & !dcmclkin_st;

  //synchronizer
  reg clkrdy_q;
  reg clkrdy_sync;
  always @ (posedge stbclk) begin
    clkrdy_q    <=#1 clkrdy;
    clkrdy_sync <=#1 clkrdy_q;
  end 

  //wait for lock timer
  parameter TIMEOUT_VALUE = 16'hffff;

  reg   [15:0] timer;
  reg   timer_rst, timer_en;
  wire  timeout;

  always @ (posedge stbclk) begin
    if(timer_rst)
      timer <=#1 16'h0;
    else if (timer_en)
      timer <=#1 timer + 1'b1;
  end

  assign timeout = (timer == TIMEOUT_VALUE);

  // Monitor FSM
  parameter IDLE  = 3'b001;
  parameter RESET = 3'b010;
  parameter WAIT  = 3'b100;

  reg [2:0] current_state = IDLE;
  reg [2:0] next_state = IDLE;

  always @ (posedge stbclk) begin
    current_state <=#1 next_state; 
  end

  always @ (*) begin
    case (current_state) //synthesis parallel_case full_case
      IDLE:
        if(clkrdy_sync)
          next_state = IDLE;
        else
          next_state = RESET;

      RESET:
        next_state = WAIT;

      WAIT:
        if(clkrdy_sync)
          next_state = IDLE;
        else if(timeout)
          next_state = RESET;
        else
          next_state = WAIT;
    endcase
  end

  always @ (posedge stbclk) begin
    case (next_state)//synthesis parallel_case full_case
      IDLE: begin
        timer_rst   <=#1 1'b1;
        timer_en    <=#1 1'b0;
        dcmrst      <=#1 1'b0;
      end

      RESET: begin
        timer_rst   <=#1 1'b1;
        timer_en    <=#1 1'b0;
        dcmrst      <=#1 1'b1;
      end
      
      WAIT: begin
        timer_rst   <=#1 1'b0;
        timer_en    <=#1 1'b1;
        if(timer[4])
          dcmrst    <=#1 1'b0;
      end
    endcase
  end 

endmodule

//////////////////////////////////////////////////////////////////////////////
//
//  Xilinx, Inc. 2007                 www.xilinx.com
//
//  XAPP 460
//
//////////////////////////////////////////////////////////////////////////////
//
//  File name :       dvi_decoder.v
//
//  Description :     Wrap around decoder for all three TMDS channels
//
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

module dvi_decoder # (
  parameter TMDS_INVERT = "FALSE"
)
(
  input  wire clkin,          // clock input from board
  input  wire tmdsclk_p,      // tmds clock
  input  wire tmdsclk_n,      // tmds clock
  input  wire blue_p,         // Blue data in
  input  wire green_p,        // Green data in
  input  wire red_p,          // Red data in
  input  wire blue_n,         // Blue data in
  input  wire green_n,        // Green data in
  input  wire red_n,          // Red data in

  output wire clk,
  output wire clkx5,
  output wire clkx5not,
  output wire reset,

  output wire hsync,          // hsync data
  output wire vsync,          // vsync data
  output wire de,             // data enable
  output wire psalgnerr,      // channel phase alignment error
  output wire [29:0] sdout,
  output wire [7:0] red,      // pixel data out
  output wire [7:0] green,    // pixel data out
  output wire [7:0] blue);    // pixel data out
    

  wire [9:0] sdout_blue, sdout_green, sdout_red;

  assign sdout = {sdout_red[9], sdout_green[9], sdout_blue[9], sdout_red[8], sdout_green[8], sdout_blue[8],
                  sdout_red[7], sdout_green[7], sdout_blue[7], sdout_red[6], sdout_green[6], sdout_blue[6],
                  sdout_red[5], sdout_green[5], sdout_blue[5], sdout_red[4], sdout_green[4], sdout_blue[4],
                  sdout_red[3], sdout_green[3], sdout_blue[3], sdout_red[2], sdout_green[2], sdout_blue[2],
                  sdout_red[1], sdout_green[1], sdout_blue[1], sdout_red[0], sdout_green[0], sdout_blue[0]} ;



  wire de_b, de_g, de_r;

  assign de = de_b;

  wire stbclk = clkin;

  wire blue_vld, green_vld, red_vld;
  wire blue_rdy, green_rdy, red_rdy;

  wire blue_psalgnerr, green_psalgnerr, red_psalgnerr;

  decode # (
    .TMDS_INVERT(TMDS_INVERT)
  ) dec_b (
    .stbclk       (stbclk),
    .clk          (clk),
    .din_p        (blue_p),
    .din_n        (blue_n),
    .other_ch0_rdy(green_rdy),
    .other_ch1_rdy(red_rdy),
    .other_ch0_vld(green_vld),
    .other_ch1_vld(red_vld),

    .clkx5        (clkx5),
    .clkx5not     (clkx5not),
    .rst          (rst_b),

    .iamvld       (blue_vld),
    .iamrdy       (blue_rdy),
    .psalgnerr    (blue_psalgnerr),
    .c0           (hsync),
    .c1           (vsync),
    .de           (de_b),
    .sdout        (sdout_blue),
    .dout         (blue)) ;

  decode # (
    .TMDS_INVERT(TMDS_INVERT)
  ) dec_g (
    .stbclk       (stbclk),
    .clk          (clk),
    .din_p        (green_p),
    .din_n        (green_n),
    .other_ch0_rdy(blue_rdy),
    .other_ch1_rdy(red_rdy),
    .other_ch0_vld(blue_vld),
    .other_ch1_vld(red_vld),

    .clkx5        (),
    .clkx5not     (),
    .rst          (rst_g),

    .iamvld       (green_vld),
    .iamrdy       (green_rdy),
    .psalgnerr    (green_psalgnerr),
    .c0           (),
    .c1           (),
    .de           (de_g),
    .sdout        (sdout_green),
    .dout         (green)) ;
    
  decode # (
    .TMDS_INVERT(TMDS_INVERT)
  ) dec_r (
    .stbclk       (stbclk),
    .clk          (clk),
    .din_p        (red_p),
    .din_n        (red_n),
    .other_ch0_rdy(blue_rdy),
    .other_ch1_rdy(green_rdy),
    .other_ch0_vld(blue_vld),
    .other_ch1_vld(green_vld),

    .clkx5        (),
    .clkx5not     (),
    .rst          (rst_r),

    .iamvld       (red_vld),
    .iamrdy       (red_rdy),
    .psalgnerr    (red_psalgnerr),
    .c0           (),
    .c1           (),
    .de           (de_r),
    .sdout        (sdout_red),
    .dout         (red)) ;

  wire rxclkint;

  IBUFDS  #(.IOSTANDARD("TMDS_33"), .IBUF_DELAY_VALUE("0"), .IFD_DELAY_VALUE("0")) 
  ibuf_clk (.I(tmdsclk_p), .IB(tmdsclk_n), .O(rxclkint));
  BUFG  clk_bufg      (.I(rxclkint),      .O(clk));

  assign psalgnerr = red_psalgnerr | blue_psalgnerr | green_psalgnerr;
  assign reset = rst_r | rst_b | rst_g;

endmodule

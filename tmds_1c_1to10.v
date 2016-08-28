//////////////////////////////////////////////////////////////////////////////
//
//  Xilinx, Inc. 2006                 www.xilinx.com
//
//  XAPP 460 - 1:10 TMDS in Spartan3A Devices
//
//////////////////////////////////////////////////////////////////////////////
//
//  File name :       tmds_1c_1to10.v
//
//  Description :     1-channel 1:10 DVI/TMDS Video frame receiver
//
//  Note:
// 	1.		data is received LSBs first
// 	   		0, 1,  2, 3, 4, 5, 6, 7, 8, 9
//
//  2.    No HDMI video/aux data guard band code allowed
//
//  3.    Video/Control data only. No aux data
//
//
//  Author :    Bob Feng 
//
//  Disclaimer: LIMITED WARRANTY AND DISCLAMER. These designs are
//              provided to you "as is". Xilinx and its licensors make and you
//              receive no warranties or conditions, express, implied,
//              statutory or otherwise, and Xilinx specifically disclaims any
//              implied warranties of merchantability, non-infringement,or
//              fitness for a particular purpose. Xilinx does not warrant that
//              the functions contained in these designs will meet your
//              requirements, or that the operation of these designs will be
//              uninterrupted or error free, or that defects in the Designs
//              will be corrected. Furthermore, Xilinx does not warrantor
//              make any representations regarding use or the results of the
//              use of the designs in terms of correctness, accuracy,
//              reliability, or otherwise.
//
//              LIMITATION OF LIABILITY. In no event will Xilinx or its
//              licensors be liable for any loss of data, lost profits,cost
//              or procurement of substitute goods or services, or for any
//              special, incidental, consequential, or indirect damages
//              arising from the use or operation of the designs or
//              accompanying documentation, however caused and on any theory
//              of liability. This limitation will apply even if Xilinx
//              has been advised of the possibility of such damage. This
//              limitation shall apply not-withstanding the failure of the
//              essential purpose of any limited remedies herein.
//
//  Copyright © 2006 Xilinx, Inc.
//  All rights reserved
//
//////////////////////////////////////////////////////////////////////////////
//
`timescale 1 ns / 1ps

module tmds_1c_1to10(
  input  wire clk,
  input	 wire clkx5,			      // x5 clock
  input  wire rst,
  input	 wire d0,               // input data from Q0 of IDDR2
  input	 wire d1,               // input data from Q1 of IDDR2
  output reg [9:0]	dataout);

  wire 	[9:0] din; 

  wire d0_q; //align d0 and d1 into same word boundary
  FD 	fd_d0q  (.C(clkx5), .D(d0),     .Q(d0q));

  FD 	fd_din8 (.C(clkx5), .D(d0q),    .Q(din[8]));
  FD 	fd_din6 (.C(clkx5), .D(din[8]), .Q(din[6]));
  FD 	fd_din4 (.C(clkx5), .D(din[6]), .Q(din[4]));
  FD 	fd_din2 (.C(clkx5), .D(din[4]), .Q(din[2]));
  FD 	fd_din0 (.C(clkx5), .D(din[2]), .Q(din[0]));

  FD 	fd_din9 (.C(clkx5), .D(d1),     .Q(din[9]));
  FD 	fd_din7 (.C(clkx5), .D(din[9]), .Q(din[7]));
  FD 	fd_din5 (.C(clkx5), .D(din[7]), .Q(din[5]));
  FD 	fd_din3 (.C(clkx5), .D(din[5]), .Q(din[3]));
  FD 	fd_din1 (.C(clkx5), .D(din[3]), .Q(din[1]));


  //////////////////////////////////////////////////////////////////////////////
  // 5 Cycle Counter for clkx5
  // Generate data latch
  //////////////////////////////////////////////////////////////////////////////
  wire [2:0] statep;
  reg [2:0] statep_d;

  parameter ST0 = 3'b000;
  parameter ST1 = 3'b001;
  parameter ST2 = 3'b011;
  parameter ST3 = 3'b111;
  parameter ST4 = 3'b110;

  always@(statep) begin
    case (statep)
      ST0     : statep_d = ST1 ;
      ST1     : statep_d = ST2 ;
      ST2     : statep_d = ST3 ;
      ST3     : statep_d = ST4 ;
      default : statep_d = ST0;
    endcase
  end

  FDC fdr_stp0 (.C(clkx5),  .D(statep_d[0]), .CLR(rst), .Q(statep[0]));
  FDC fdr_stp1 (.C(clkx5),  .D(statep_d[1]), .CLR(rst), .Q(statep[1]));
  FDC fdr_stp2 (.C(clkx5),  .D(statep_d[2]), .CLR(rst), .Q(statep[2]));

  wire latch_d, latch;
  assign latch_d = (statep == ST3);
  FD fd_latch (.C(clkx5), .D(latch_d), .Q(latch));

  wire [9:0] din_q;
  FD 	fd_dinq0 (.C(clkx5), .D(din[0]), .Q(din_q[0]));
  FD 	fd_dinq1 (.C(clkx5), .D(din[1]), .Q(din_q[1]));
  FD 	fd_dinq2 (.C(clkx5), .D(din[2]), .Q(din_q[2]));
  FD 	fd_dinq3 (.C(clkx5), .D(din[3]), .Q(din_q[3]));
  FD 	fd_dinq4 (.C(clkx5), .D(din[4]), .Q(din_q[4]));
  FD 	fd_dinq5 (.C(clkx5), .D(din[5]), .Q(din_q[5]));
  FD 	fd_dinq6 (.C(clkx5), .D(din[6]), .Q(din_q[6]));
  FD 	fd_dinq7 (.C(clkx5), .D(din[7]), .Q(din_q[7]));
  FD 	fd_dinq8 (.C(clkx5), .D(din[8]), .Q(din_q[8]));
  FD 	fd_dinq9 (.C(clkx5), .D(din[9]), .Q(din_q[9]));

  ////////////////////////////////////////////////////
  // Here we instantiate a 16x30 Dual Port RAM
  // and latch the recovered data (10 bit) into it
  ////////////////////////////////////////////////////
  wire  [3:0]   wa;       // RAM read address
  reg   [3:0]   wa_d;     // RAM read address
  wire  [3:0]   ra;       // RAM read address
  reg   [3:0]   ra_d;     // RAM read address

  parameter ADDR0  = 4'b0000;
  parameter ADDR1  = 4'b0001;
  parameter ADDR2  = 4'b0010;
  parameter ADDR3  = 4'b0011;
  parameter ADDR4  = 4'b0100;
  parameter ADDR5  = 4'b0101;
  parameter ADDR6  = 4'b0110;
  parameter ADDR7  = 4'b0111;
  parameter ADDR8  = 4'b1000;
  parameter ADDR9  = 4'b1001;
  parameter ADDR10 = 4'b1010;
  parameter ADDR11 = 4'b1011;
  parameter ADDR12 = 4'b1100;
  parameter ADDR13 = 4'b1101;
  parameter ADDR14 = 4'b1110;
  parameter ADDR15 = 4'b1111;

  always@(wa) begin
    case (wa)
      ADDR0   : wa_d = ADDR1 ;
      ADDR1   : wa_d = ADDR2 ;
      ADDR2   : wa_d = ADDR3 ;
      ADDR3   : wa_d = ADDR4 ;
      ADDR4   : wa_d = ADDR5 ;
      ADDR5   : wa_d = ADDR6 ;
      ADDR6   : wa_d = ADDR7 ;
      ADDR7   : wa_d = ADDR8 ;
      ADDR8   : wa_d = ADDR9 ;
      ADDR9   : wa_d = ADDR10;
      ADDR10  : wa_d = ADDR11;
      ADDR11  : wa_d = ADDR12;
      ADDR12  : wa_d = ADDR13;
      ADDR13  : wa_d = ADDR14;
      ADDR14  : wa_d = ADDR15;
      default : wa_d = ADDR0;
    endcase
  end

  wire rstsync, warst;
  (* ASYNC_REG = "TRUE" *) FDP fdp_rst  (.C(clkx5),  .D(rst), .PRE(rst), .Q(rstsync));
  FD fd_rstp    (.C(clkx5), .D(rstsync), .Q(warst));

  FDRE fdr_wa0 (.C(clkx5), .D(wa_d[0]), .CE(latch), .R(warst), .Q(wa[0]));
  FDRE fdr_wa1 (.C(clkx5), .D(wa_d[1]), .CE(latch), .R(warst), .Q(wa[1]));
  FDRE fdr_wa2 (.C(clkx5), .D(wa_d[2]), .CE(latch), .R(warst), .Q(wa[2]));
  FDRE fdr_wa3 (.C(clkx5), .D(wa_d[3]), .CE(latch), .R(warst), .Q(wa[3]));

  //Dual Port fifo to bridge data through
  wire [9:0] dpfo_dout;
  DRAM16XN #(.data_width(10))
  fifo_u (
         .DATA_IN(din_q),
         .ADDRESS(wa),
         .ADDRESS_DP(ra),
         .WRITE_EN(latch),
         .CLK(clkx5),
         .O_DATA_OUT(),
         .O_DATA_OUT_DP(dpfo_dout));

  /////////////////////////////////////////////////////////////////
  // FIFO read is set to be contiguous in order to keep up pace
  // with the fifo write speed: every 5 clkx5 cycles.
  // Also FIFO read reset is delayed a bit in order to avoid
  // underflow.
  /////////////////////////////////////////////////////////////////
  wire rdrst;

  SRL16 SRL16_0 (
    .Q(rdrst),
    .A0(1'b1),
    .A1(1'b1),
    .A2(1'b1),
    .A3(1'b1),
    .CLK(clkx5),
    .D(warst)
  );
  // The following defparam declaration 
  defparam SRL16_0.INIT = 16'h0;

  always@(ra) begin
    case (ra)
      ADDR0   : ra_d = ADDR1 ;
      ADDR1   : ra_d = ADDR2 ;
      ADDR2   : ra_d = ADDR3 ;
      ADDR3   : ra_d = ADDR4 ;
      ADDR4   : ra_d = ADDR5 ;
      ADDR5   : ra_d = ADDR6 ;
      ADDR6   : ra_d = ADDR7 ;
      ADDR7   : ra_d = ADDR8 ;
      ADDR8   : ra_d = ADDR9 ;
      ADDR9   : ra_d = ADDR10;
      ADDR10  : ra_d = ADDR11;
      ADDR11  : ra_d = ADDR12;
      ADDR12  : ra_d = ADDR13;
      ADDR13  : ra_d = ADDR14;
      ADDR14  : ra_d = ADDR15;
      default : ra_d = ADDR0;
    endcase
  end

  //rdrst is only synced to clkx5 so use async. reset here
  FDC fdc_ra0 (.C(clk), .D(ra_d[0]), .CLR(rdrst), .Q(ra[0]));
  FDC fdc_ra1 (.C(clk), .D(ra_d[1]), .CLR(rdrst), .Q(ra[1]));
  FDC fdc_ra2 (.C(clk), .D(ra_d[2]), .CLR(rdrst), .Q(ra[2]));
  FDC fdc_ra3 (.C(clk), .D(ra_d[3]), .CLR(rdrst), .Q(ra[3]));

  always @ (posedge clk) begin
    dataout <=#1 dpfo_dout;
  end
endmodule

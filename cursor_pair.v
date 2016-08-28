//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2007 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor:        Xilinx
// \   \   \/    Version:       1.0.0
//  \   \        Filename:      cursor_pair.v
//  /   /        Date Created:  July 1, 2007
// /___/   /\    Last Modified: July 1, 2007
// \   \  /  \
//  \___\/\___\
//
// Devices:   Spartan-3 Generation FPGA
// Purpose:   Dual-ported block ROM
// Contact:   crabill@xilinx.com
// Reference: None
//
// Revision History:
//   Rev 1.0.0 - (crabill) First created July 1, 2007.
//
//////////////////////////////////////////////////////////////////////////////
//
// LIMITED WARRANTY AND DISCLAIMER. These designs are provided to you "as is".
// Xilinx and its licensors make and you receive no warranties or conditions,
// express, implied, statutory or otherwise, and Xilinx specifically disclaims
// any implied warranties of merchantability, non-infringement, or fitness for
// a particular purpose. Xilinx does not warrant that the functions contained
// in these designs will meet your requirements, or that the operation of
// these designs will be uninterrupted or error free, or that defects in the
// designs will be corrected. Furthermore, Xilinx does not warrant or make any
// representations regarding use or the results of the use of the designs in
// terms of correctness, accuracy, reliability, or otherwise.
//
// LIMITATION OF LIABILITY. In no event will Xilinx or its licensors be liable
// for any loss of data, lost profits, cost or procurement of substitute goods
// or services, or for any special, incidental, consequential, or indirect
// damages arising from the use or operation of the designs or accompanying
// documentation, however caused and on any theory of liability. This
// limitation will apply even if Xilinx has been advised of the possibility
// of such damage. This limitation shall apply not-withstanding the failure
// of the essential purpose of any limited remedies herein.
//
//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2007 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ps

module cursor_pair
  #(
  parameter          IMAGE = "XILINX"
  )
  (
  input  wire [11:0] xidx0,
  input  wire [11:0] yidx0,
  output reg   [1:0] data0,
  output reg         mask0,
  input  wire [11:0] xidx1,
  input  wire [11:0] yidx1,
  output reg   [1:0] data1,
  output reg         mask1,
  input  wire        clk
  );

  //******************************************************************//
  // Generate address signals and other helpers...                    //
  //******************************************************************//

  wire   [15:0] idx0_addr;
  wire          idx0_maskx;
  wire          idx0_masky;

  assign idx0_addr = {yidx0[7:0], xidx0[7:0]};
  assign idx0_maskx = | xidx0[11:8];
  assign idx0_masky = | yidx0[11:8];

  wire   [15:0] idx1_addr;
  wire          idx1_maskx;
  wire          idx1_masky;

  assign idx1_addr = {yidx1[7:0], xidx1[7:0]};
  assign idx1_maskx = | xidx1[11:8];
  assign idx1_masky = | yidx1[11:8];

  //******************************************************************//
  // Both ports are organized as x2 data output.                      //
  //******************************************************************//
 
  wire [1:0] hwc_a0_out;
  wire [1:0] hwc_b0_out;
  wire [1:0] hwc_a1_out;
  wire [1:0] hwc_b1_out;
  wire [1:0] hwc_a2_out;
  wire [1:0] hwc_b2_out;
  wire [1:0] hwc_a3_out;
  wire [1:0] hwc_b3_out;
  wire [1:0] hwc_a4_out;
  wire [1:0] hwc_b4_out;
  wire [1:0] hwc_a5_out;
  wire [1:0] hwc_b5_out;

  `include "s3a_logo.v"

  //******************************************************************//
  // Pipelined output mux for read data...                            //
  //******************************************************************//

  reg [2:0]         select_a;
  reg [2:0]         select_b;
  reg           idx0_maskx_dly;
  reg           idx0_masky_dly;
  reg           idx1_maskx_dly;
  reg           idx1_masky_dly;

  always @(posedge clk)
  begin
    select_a <= idx0_addr[15:13];
    select_b <= idx1_addr[15:13];

    case (select_a)
      3'b000:
        data0 <= hwc_a0_out;
      3'b001:
        data0 <= hwc_a1_out;
      3'b010:
        data0 <= hwc_a2_out;
      3'b011:
        data0 <= hwc_a3_out;
      3'b100:
        data0 <= hwc_a4_out;
      3'b101:
        data0 <= hwc_a5_out;
      default:
        data0 <= 2'b00;
    endcase

    case (select_b)
      3'b000:
        data1 <= hwc_b0_out;
      3'b001:
        data1 <= hwc_b1_out;
      3'b010:
        data1 <= hwc_b2_out;
      3'b011:
        data1 <= hwc_b3_out;
      3'b100:
        data1 <= hwc_b4_out;
      3'b101:
        data1 <= hwc_b5_out;
      default:
        data1 <= 2'b00;
    endcase

    idx0_maskx_dly <= idx0_maskx;
    idx0_masky_dly <= idx0_masky;
    idx1_maskx_dly <= idx1_maskx;
    idx1_masky_dly <= idx1_masky;
    mask0 <= idx0_maskx_dly || idx0_masky_dly;
    mask1 <= idx1_maskx_dly || idx1_masky_dly;
  end

  //******************************************************************//
  //                                                                  //
  //******************************************************************//

endmodule

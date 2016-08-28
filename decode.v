//////////////////////////////////////////////////////////////////////////////
//
//  Xilinx, Inc. 2007                 www.xilinx.com
//
//  XAPP xxx
//
//////////////////////////////////////////////////////////////////////////////
//
//  File name :       decoder.v
//
//  Description :     dvi decoder 
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

module decode # (
  parameter TMDS_INVERT = "FALSE"
)
(
  input  wire stbclk,           //stable clock from board: Only used to generate reset
  input  wire clk,              //clk from dvi cable
  input  wire din_p,            //data from dvi cable
  input  wire din_n,            //data from dvi cable
  input  wire other_ch0_vld,    //other channel0 has valid data now
  input  wire other_ch1_vld,    //other channel1 has valid data now
  input  wire other_ch0_rdy,    //other channel0 has detected a valid starting pixel
  input  wire other_ch1_rdy,    //other channel1 has detected a valid starting pixel

  output wire clkx5,
  output wire clkx5not,
  output wire rst,

  output wire iamvld,           //I have valid data now
  output wire iamrdy,           //I have detected a valid new pixel
  output wire psalgnerr,        //Phase alignment error
  output reg c0,
  output reg c1,
  output reg de,     
  output reg [9:0] sdout,
  output reg [7:0] dout);

  wire dint, d0, d1;
  wire dcmlck;
  wire dcmrst;
  wire [7:0] dcm_status;

  dcminit dcminit_0(
    .stbclk(stbclk),
    .dcmlck(dcmlck),
    .dcmclkin_st(dcm_status[1]),
    .dcmrst(dcmrst)
  );

  IBUFDS #(.IOSTANDARD("TMDS_33"), .IFD_DELAY_VALUE("0"), .DIFF_TERM("FALSE"))
  ibufdin (.I(din_p), .IB(din_n), .O(dint));

  IDDR2 #(.DDR_ALIGNMENT("C0"))
  fddrdin (
          .C0(clkx5),
          .C1(clkx5not), 
          .D(dint),
          .CE(1'b1),
          .R(1'b0),
          .S(1'b0),
          .Q0(d0),
          .Q1(d1));

  wire clkx5dcm, clkx5notdcm;
  wire psen, psincdec;

  wire clk_fdbk;

  DCM_SP #(
    .CLKIN_PERIOD       (13),
    .CLKFX_DIVIDE	      (1),	
    .CLKFX_MULTIPLY	    (5),
    .CLKOUT_PHASE_SHIFT ("VARIABLE"),
    .PHASE_SHIFT        (0), 
    .DESKEW_ADJUST      ("SOURCE_SYNCHRONOUS"))
  dcm_rxclk (
    .CLKIN    (clk),
    .CLKFB    (clk_fdbk),
    .DSSEN    (1'b0),
    .PSINCDEC (psincdec),
    .PSEN     (psen),
    .PSCLK    (clk),
    .RST      (dcmrst),
    .CLK0     (clk_fdbk),
    .CLK90    (),
    .CLK180   (),
    .CLK270   (),
    .CLK2X    (),
    .CLK2X180 (),
    .CLKDV    (),
    .CLKFX    (clkx5dcm),
    .CLKFX180 (clkx5notdcm),
    .LOCKED   (dcmlck),
    .PSDONE   (psdone),
    .STATUS   (dcm_status)) ;

  BUFG  clkx5_bufg    (.I(clkx5dcm),    .O(clkx5));
  BUFG  clkx5not_bufg (.I(clkx5notdcm), .O(clkx5not));

  assign rst = !(dcmlck === 1'b1); //~dcmlck;

  wire tmds_d0, tmds_d1;

  assign tmds_d0 = (TMDS_INVERT == "TRUE") ? ~d0 : d0;
  assign tmds_d1 = (TMDS_INVERT == "TRUE") ? ~d1 : d1;

  wire [9:0] rawword;
  tmds_1c_1to10 des (
    .clk(clk),
    .clkx5(clkx5),
    .rst(rst),
    .d0(tmds_d0), 
    .d1(tmds_d1), 
    .dataout(rawword)
  );

  /////////////////////////////////////////////////////
  // Doing word boundary detection here
  /////////////////////////////////////////////////////

  // Distinct Control Tokens
  parameter CTRLTOKEN0 = 10'b1101010100;
  parameter CTRLTOKEN1 = 10'b0010101011;
  parameter CTRLTOKEN2 = 10'b0101010100;
  parameter CTRLTOKEN3 = 10'b1010101011;

  reg [9:0] rawword_q;

  always @ (posedge clk) begin
    rawword_q <=#1 rawword;
  end

  wire found_vld_openeye;

  wire [19:0] two_raw_words = {rawword, rawword_q};

  reg [9:0] word_sel;
  always @ (posedge clk or posedge rst) begin
    if(rst)
      word_sel <= 10'h1;
    else if(!found_vld_openeye)
      casez (two_raw_words)
        {CTRLTOKEN0, 10'b??????????}:
          word_sel <=#1 10'h1;

        {1'b?, CTRLTOKEN0, 9'b?????????}:
          word_sel <=#1 10'h1 << 1;

        {2'b??, CTRLTOKEN0, 8'b????????}:
          word_sel <=#1 10'h1 << 2;

        {3'b???, CTRLTOKEN0, 7'b???????}:
          word_sel <=#1 10'h1 << 3;

        {4'b????, CTRLTOKEN0, 6'b??????}:
          word_sel <=#1 10'h1 << 4;

        {5'b?????, CTRLTOKEN0, 5'b?????}:
          word_sel <=#1 10'h1 << 5;

        {6'b??????, CTRLTOKEN0, 4'b????}:
          word_sel <=#1 10'h1 << 6;

        {7'b???????, CTRLTOKEN0, 3'b???}:
          word_sel <=#1 10'h1 << 7;

        {8'b????????, CTRLTOKEN0, 2'b??}:
          word_sel <=#1 10'h1 << 8;

        {9'b?????????, CTRLTOKEN0, 1'b?}:
          word_sel <=#1 10'h1 << 9;

        default:
          word_sel <=#1 word_sel;
      endcase
  end

  reg [9:0] rawdata;
  always @ (posedge clk or posedge rst) begin
    if(rst)
      rawdata <= 10'h0;
    else
      case (1'b1) // synthesis parallel_case full_case
        word_sel[0]:
          rawdata <=#1 rawword;

        word_sel[1]:
          rawdata <=#1 {rawword[8:0], rawword_q[9]};

        word_sel[2]:
          rawdata <=#1 {rawword[7:0], rawword_q[9:8]};

        word_sel[3]:
          rawdata <=#1 {rawword[6:0], rawword_q[9:7]};

        word_sel[4]:
          rawdata <=#1 {rawword[5:0], rawword_q[9:6]};

        word_sel[5]:
          rawdata <=#1 {rawword[4:0], rawword_q[9:5]};

        word_sel[6]:
          rawdata <=#1 {rawword[3:0], rawword_q[9:4]};

        word_sel[7]:
          rawdata <=#1 {rawword[2:0], rawword_q[9:3]};

        word_sel[8]:
          rawdata <=#1 {rawword[1:0], rawword_q[9:2]};

        word_sel[9]:
          rawdata <=#1 {rawword[0], rawword_q[9:1]};
      endcase
  end

  ///////////////////////////////////////
  // Phase Alignment Instance
  ///////////////////////////////////////
  wire phsalgn_err;
  reg  phsalgn_err_q, phsalgn_err_rising;

  always @ (posedge clk) begin
    phsalgn_err_q <=#1 phsalgn_err;
    phsalgn_err_rising <=#1 phsalgn_err & !phsalgn_err_q;
  end

  phsaligner phsalgn_0 (
    .rst(rst | phsalgn_err_rising),
    .clk(clk),
    .sdata(rawdata),
    .psdone(psdone),
    .dcm_ovflw(dcm_status[0]),
    .found_vld_openeye(found_vld_openeye),
    .psen(psen),
    .psincdec(psincdec),
    .psaligned(iamvld), //achieved phase lock
    .psalgnerr(phsalgn_err)
  );

  assign psalgnerr = phsalgn_err;

  wire [9:0] sdata;
  chnlbond cbnd (
    .clk(clk),
    .rawdata(rawdata),
    .iamvld(iamvld),
    .other_ch0_vld(other_ch0_vld),
    .other_ch1_vld(other_ch1_vld),
    .other_ch0_rdy(other_ch0_rdy),
    .other_ch1_rdy(other_ch1_rdy),
    .iamrdy(iamrdy),
    .sdata(sdata)
  );

  /////////////////////////////////////////////////////////////////
  // Below performs the 10B-8B decoding function defined in DVI 1.0
  // Specification: Section 3.3.3, Figure 3-6, page 31. 
  /////////////////////////////////////////////////////////////////
  wire [7:0] data;
  assign data = (sdata[9]) ? ~sdata[7:0] : sdata[7:0]; 

  always @ (posedge clk) begin
    if(iamrdy && other_ch0_rdy && other_ch1_rdy) begin
      case (sdata) 
        CTRLTOKEN0: begin
          c0 <=#1 1'b0;
          c1 <=#1 1'b0;
          de <=#1 1'b0;
        end

        CTRLTOKEN1: begin
          c0 <=#1 1'b1;
          c1 <=#1 1'b0;
          de <=#1 1'b0;
        end

        CTRLTOKEN2: begin
          c0 <=#1 1'b0;
          c1 <=#1 1'b1;
          de <=#1 1'b0;
        end
        
        CTRLTOKEN3: begin
          c0 <=#1 1'b1;
          c1 <=#1 1'b1;
          de <=#1 1'b0;
        end
        
        default: begin 
          dout[0] <=#1 data[0];
          dout[1] <=#1 (sdata[8]) ? (data[1] ^ data[0]) : (data[1] ~^ data[0]);
          dout[2] <=#1 (sdata[8]) ? (data[2] ^ data[1]) : (data[2] ~^ data[1]);
          dout[3] <=#1 (sdata[8]) ? (data[3] ^ data[2]) : (data[3] ~^ data[2]);
          dout[4] <=#1 (sdata[8]) ? (data[4] ^ data[3]) : (data[4] ~^ data[3]);
          dout[5] <=#1 (sdata[8]) ? (data[5] ^ data[4]) : (data[5] ~^ data[4]);
          dout[6] <=#1 (sdata[8]) ? (data[6] ^ data[5]) : (data[6] ~^ data[5]);
          dout[7] <=#1 (sdata[8]) ? (data[7] ^ data[6]) : (data[7] ~^ data[6]);

          de <=#1 1'b1;
        end                                                                      
      endcase                                                                    

      sdout <=#1 sdata;
    end else begin
      c0 <= 1'b0;
      c1 <= 1'b0;
      de <= 1'b0;
      dout <= 8'h0;
      sdout <= 10'h0;
    end
  end
endmodule

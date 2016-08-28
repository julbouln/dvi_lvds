//////////////////////////////////////////////////////////////////////////////
//
//  Xilinx, Inc. 2006                 www.xilinx.com
//
//  XAPP 460 - TMDS serial stream phase aligner
//
//////////////////////////////////////////////////////////////////////////////
//
//  File name :       phasealigner.v
//
//  Description :     This module tries to achieve phase alignment between
//                    recovered bit clock and incoming serila data stream.
//
//  Note:             
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

module phsaligner # (
  parameter CTKNCNTWD   = 7,       //Control Token Counter Width
  parameter CTKNCNTFULL = 7'h7f,   //Control Token Counter Full
  parameter SRCHTIMERWD = 12,      //Search Timer Width
  parameter SRCHTIMEOUT = 12'hfff  //Search Timer Time Out Value
)
(
  input  wire       rst,
  input  wire       clk,
  input  wire [9:0] sdata,       //10 bit serial stream sync. to clk
  input  wire       psdone,
  input  wire       dcm_ovflw,
  output reg        found_vld_openeye,
  output reg        psen,        //output to DCM
  output reg        psincdec,    //output to DCM
  output reg        psaligned,   //achieved phase alignment
  output reg        psalgnerr
);  

  parameter CTRLTOKEN0 = 10'b1101010100;
  parameter CTRLTOKEN1 = 10'b0010101011;
  parameter CTRLTOKEN2 = 10'b0101010100;
  parameter CTRLTOKEN3 = 10'b1010101011;

  ///////////////////////////////////////////////////////
  // Control Token Detection
  ///////////////////////////////////////////////////////
  reg rcvd_ctkn, rcvd_ctkn_q; //received control token
  reg blnkbgn; //blank period begins

  always @ (posedge clk) begin
    rcvd_ctkn <=#1 ((sdata == CTRLTOKEN0) || (sdata == CTRLTOKEN1) || (sdata == CTRLTOKEN2) || (sdata == CTRLTOKEN3));
    rcvd_ctkn_q <=#1 rcvd_ctkn;
    blnkbgn <=#1 !rcvd_ctkn_q & rcvd_ctkn;
  end

  /////////////////////////////////////////////////////
  // Control Token Search Timer
  //
  // DVI 1.0 Spec. says periodic blanking should start
  // no less than every 50ms or 20HZ
  // 2^24 of 74.25MHZ cycles is about 200ms
  /////////////////////////////////////////////////////
  reg [(SRCHTIMERWD-1):0] ctkn_srh_timer;
  reg ctkn_srh_rst;

  always @ (posedge clk) begin
    if (ctkn_srh_rst)
      ctkn_srh_timer <=#1 12'h0;
    else
      ctkn_srh_timer <=#1 ctkn_srh_timer + 1'b1; 
  end

  reg ctkn_srh_tout;
  always @ (posedge clk) begin
    ctkn_srh_tout <=#1 (ctkn_srh_timer == SRCHTIMEOUT);
  end

  /////////////////////////////////////////////////////
  // Contorl Token Event Counter
  //
  // DVI 1.0 Spec. says the minimal blanking period
  // is at least 128 pixels long in order to achieve
  // synchronization
  //
  // We only search for 16 control tokens here
  /////////////////////////////////////////////////////
  reg [(CTKNCNTWD-1):0] ctkn_counter;
  reg ctkn_cnt_rst;
  
  always @ (posedge clk) begin
    if(ctkn_cnt_rst)
      ctkn_counter <=#1 7'h0;
    else
      ctkn_counter <=#1 ctkn_counter + 1'b1;
  end

  reg ctkn_cnt_tout;
  always @ (posedge clk) begin
    ctkn_cnt_tout <=#1 (ctkn_counter == CTKNCNTFULL);
  end

  /////////////////////////////////////////////////////////
  // DCM Phase Shift Counter: Count Number of Phase Steps
  //
  // This serves two purposes:
  // 1. Record the phase shift value
  // 2. Ensure the full range of DCM phase shift has been
  //    covered
  /////////////////////////////////////////////////////////
  reg init_phs_done; //flag to set if the initial phase shift is done

  reg [9:0] ps_cnt;
  reg ps_cnt_rst;
  reg psinc_cnt_en, psdec_cnt_en;
  always @ (posedge clk or posedge rst) begin
    //if(ps_cnt_rst)
    if(rst)
      ps_cnt <=#1 10'h0;
    else if(psen && psinc_cnt_en)
      ps_cnt <=#1 ps_cnt + 1'b1;
    else if(psen && psdec_cnt_en && init_phs_done)
      ps_cnt <=#1 ps_cnt - 1'b1;
  end

  reg ps_cnt_full;
  always @ (posedge clk) begin
    ps_cnt_full <=#1 ps_cnt[9]; //(ps_cnt == 10'h3ff);
  end

  //////////////////////////////////////////////////////////
  // Decrement counter: Used to go back to the middle of
  //                    an open eye.
  // T1: openeye_bgn T2: jtrzone_bgn
  // T2 > T1 has to be guaranteed
  // formula: pscntr needs to go back to:
  //          T1 + (T2 - T1)/2 = T1/2 + T2/2 = (T1 + T2)/2
  //////////////////////////////////////////////////////////
  reg [9:0] openeye_bgn, jtrzone_bgn;

  reg psdec_cnt_end;
  always @ (posedge clk) begin
    psdec_cnt_end <=#1 (ps_cnt == ((openeye_bgn + jtrzone_bgn) >> 1));
    //psdec_cnt_end <=#1 (ps_cnt == (openeye_bgn + ((jtrzone_bgn - openeye_bgn) >> 1)));
  end

  reg invalid_alignment;
  always @ (posedge clk) begin
`ifdef SIMULATION
    invalid_alignment <=#1 ((ps_cnt - openeye_bgn) < 10'd9);
`else
    invalid_alignment <=#1 ((ps_cnt - openeye_bgn) < 10'd30);
`endif
  end
 
  //////////////////////////////////////////////
  // This flag indicates whether we have
  // found a valid open eye or not.
  //////////////////////////////////////////////
  reg found_jtrzone;
  //reg found_vld_openeye;
`ifdef SIMULATION
  reg [2:0] openeye_counter; //to make sure the eye found is valid

  parameter OPENEYE_CNTER_RST  = 3'b000;
  parameter OPENEYE_CNTER_FULL = 3'b111;
`else
  reg [3:0] openeye_counter; //to make sure the eye found is valid

  parameter OPENEYE_CNTER_RST  = 4'b0000;
  parameter OPENEYE_CNTER_FULL = 4'b1111;
`endif

  //////////////////////////////////////////////////////////
  // Below starts the phase alignment state machine
  //////////////////////////////////////////////////////////
  reg [11:0] cstate = 12'b1;  //current and next states
  reg [11:0] nstate;

  parameter INITDEC     = 12'b1 << 0;  // Initial Phase Decrements all the way to the left
  parameter INITDECDONE = 12'b1 << 1;  // 
  parameter IDLE        = 12'b1 << 2;  //
  parameter PSINC       = 12'b1 << 3;  // Phase Incrementing
  parameter PSINCDONE   = 12'b1 << 4;  // Wait for psdone from DCM for phase incrementing
  parameter PSDEC       = 12'b1 << 5;  // Phase Decrementing
  parameter PSDECDONE   = 12'b1 << 6;  // Wait for psdone from DCM for phase decrementing
  parameter RCVDCTKN    = 12'b1 << 7;  // Received at one Control Token and check for more
  parameter EYEOPENS    = 12'b1 << 8;  // Determined in eye opening zone
  parameter JTRZONE     = 12'b1 << 9;  // Determined in jitter zone
  parameter PSALGND     = 12'b1 << 10; // Phase alignment achieved
  parameter PSALGNERR   = 12'b1 << 11; // Phase alignment error

`ifdef SIMULATION
  // synthesis translate_off
  reg  [8*20:1] state_ascii;
  always @(cstate)
  begin
    if      (cstate == IDLE       ) state_ascii <= "IDLE                "; 
    else if (cstate == PSINC      ) state_ascii <= "PSINC               ";
    else if (cstate == PSINCDONE  ) state_ascii <= "PSINCDONE           ";
    else if (cstate == PSDEC      ) state_ascii <= "PSDEC               ";
    else if (cstate == PSDECDONE  ) state_ascii <= "PSDECDONE           ";
    else if (cstate == RCVDCTKN   ) state_ascii <= "RCVDCTKN            ";
    else if (cstate == EYEOPENS   ) state_ascii <= "EYEOPENS            ";
    else if (cstate == JTRZONE    ) state_ascii <= "JTRZONE             ";
    else if (cstate == PSALGND    ) state_ascii <= "PSALGND             ";
    else if (cstate == INITDEC    ) state_ascii <= "INITDEC             ";
    else if (cstate == INITDECDONE) state_ascii <= "INITDECDONE         ";
    else state_ascii                            <= "PSALGNERR           ";
  end
  // synthesis translate_on
`endif

  always @ (posedge clk or posedge rst) begin
    if (rst)
      cstate <= INITDEC;
    else
      cstate <=#1 nstate;
  end  

  always @ (*) begin
    case (cstate) //synthesis parallel_case full_case
      INITDEC: begin
        nstate = INITDECDONE;
      end

      INITDECDONE: begin
        if(psdone)
          nstate = (dcm_ovflw) ? IDLE : INITDEC;
        else
          nstate = INITDECDONE;
      end
 
      IDLE: begin
        if(blnkbgn)
          nstate = RCVDCTKN;
        else
          if(ctkn_srh_tout)
            nstate = JTRZONE;
          else
            nstate = (ps_cnt_full) ? PSALGNERR : IDLE;
      end

      RCVDCTKN: begin
        if(rcvd_ctkn)
          nstate = (ctkn_cnt_tout) ? EYEOPENS : RCVDCTKN;
        else
          nstate = IDLE;
      end

      EYEOPENS: begin
        nstate = PSINC;
      end 

      JTRZONE: begin
        if(!found_vld_openeye)
          nstate = PSINC;
        else
          nstate = invalid_alignment ? PSALGNERR : PSDEC;
      end

      PSINC: begin //set psen
        nstate = PSINCDONE;
      end

      PSINCDONE: begin //wait for psdone here
        if(psdone)
          nstate = (dcm_ovflw) ? PSALGNERR : IDLE;
        else
          nstate = PSINCDONE;
      end

      PSDEC: begin
        nstate = PSDECDONE;
      end

      PSDECDONE: begin
        if(psdone)
          nstate = (psdec_cnt_end) ? PSALGND : PSDEC;
        else
          nstate = PSDECDONE;
      end

      PSALGND: begin  //Phase alignment achieved here 
        nstate = PSALGND;
      end

      PSALGNERR: begin //Alignment failed when all 255 phases have been tried
        nstate = PSALGNERR;
      end
    endcase
  end

  reg [9:0] last_openeye_pos;

  always @ (posedge clk or posedge rst) begin
    if(rst) begin
      psen               <=#1 1'b0; //DCM phase shift enable
      psincdec           <=#1 1'b0; //DCM phase increment or decrement

      init_phs_done      <=#1 1'b0;
      
      psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
      ps_cnt_rst         <=#1 1'b1; //phase shift increment counter reset
      psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
      openeye_bgn        <=#1 10'h0; //stores phase value of the beginning of an open eye
      jtrzone_bgn        <=#1 10'h0; //stores phase value of the beginning of a jitter zone
      last_openeye_pos   <=#1 10'h0;

      found_vld_openeye  <=#1 1'b0; //flag shows jitter zone has been reached at least once
      found_jtrzone      <=#1 1'b0; //flag shows jitter zone has been reached at least once
      psalgnerr          <=#1 1'b0; //phase alignment failure flag

      openeye_counter    <=#1 OPENEYE_CNTER_RST;
  
      psaligned          <=#1 1'b0; //phase alignment success flag
      ctkn_srh_rst       <=#1 1'b1; //control token search timer reset
      ctkn_cnt_rst       <=#1 1'b1; //control token counter reset
    end else begin
      case (cstate) // synthesis parallel_case full_case
        INITDEC: begin
          psen               <=#1 1'b1;
          psincdec           <=#1 1'b0;
          init_phs_done      <=#1 1'b0;
        end

        INITDECDONE: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b0;
          init_phs_done      <=#1 1'b0;
        end

        IDLE: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b1;

          init_phs_done      <=#1 1'b1;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b0;
          ctkn_cnt_rst       <=#1 1'b1;
        end

        RCVDCTKN: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b1;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b0;
          ctkn_cnt_rst       <=#1 1'b0;
        end

        PSINC: begin
          psen               <=#1 1'b1;
          psincdec           <=#1 1'b1;

          psinc_cnt_en       <=#1 1'b1; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b1;
          ctkn_cnt_rst       <=#1 1'b1;
        end

        PSINCDONE: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b1;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b1;
          ctkn_cnt_rst       <=#1 1'b1;
        end

        EYEOPENS: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b1;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable

          if(found_jtrzone) begin
            if((ps_cnt - last_openeye_pos) == 10'b1) begin
              openeye_counter <=#1 openeye_counter + 1'b1;

              if(openeye_counter == OPENEYE_CNTER_FULL)
                found_vld_openeye <=#1 1'b1;
            end else begin
            //whenever find the openeye sweep is no longer continuous, reset openeye_bgn
            //and openeye_counter
              openeye_bgn     <=#1 ps_cnt;
              openeye_counter <=#1 OPENEYE_CNTER_RST;
            end
          end

          last_openeye_pos   <=#1 ps_cnt;

          psalgnerr          <=#1 1'b0; //phase alignment failure flag
          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b1;
          ctkn_cnt_rst       <=#1 1'b1;
        end 

        JTRZONE: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b1;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
          jtrzone_bgn        <=#1 ps_cnt; //stores phase value of the beginning of a jitter zone
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b1;
          ctkn_cnt_rst       <=#1 1'b1;

          found_jtrzone      <=#1 1'b1;
        end

        PSDEC: begin
          psen               <=#1 1'b1;
          psincdec           <=#1 1'b0;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b1; //phase shift decrement counter enable
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b1;
          ctkn_cnt_rst       <=#1 1'b1;
        end

        PSDECDONE: begin
          psen               <=#1 1'b0;
          psincdec           <=#1 1'b0;

          psinc_cnt_en       <=#1 1'b0; //phase shift increment counter enable
          ps_cnt_rst         <=#1 1'b0; //phase shift increment counter reset
          psdec_cnt_en       <=#1 1'b0; //phase shift decrement counter enable
          psalgnerr          <=#1 1'b0; //phase alignment failure flag

          psaligned          <=#1 1'b0;
          ctkn_srh_rst       <=#1 1'b1;
          ctkn_cnt_rst       <=#1 1'b1;
        end

        PSALGND: begin
          psaligned          <=#1 1'b1;
        end

        PSALGNERR: begin
          psalgnerr          <=#1 1'b1; //phase alignment failure flag
        end
      endcase
    end 
  end

endmodule

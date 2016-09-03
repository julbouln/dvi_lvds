`timescale 1 ns / 1 ps

module dvi_lvds (
  input  wire       CLK50,
  input wire [3:0]  RX_TMDS,
  input wire [3:0]  RX_TMDSB,

output channel1_p,
	 output channel1_n,
	 output channel2_p,
	 output channel2_n,
	 output channel3_p,
	 output channel3_n,
	 output clock_p,
	 output clock_n
);

  //******************************************************************//
  // Create global clock and synchronous system reset.                //
  //******************************************************************//
  wire          clkin;
  wire          clk;
  wire          clkx5;
  wire          clkx5not;

  BUFG   stbclk_bufg (.I(CLK50), .O(clkin));

  wire rx_hsync;          // hsync data
  wire rx_vsync;          // vsync data
  wire rx_de;             // data enable
  wire rx_psalgnerr;      // channel phase alignment error
  wire [7:0] rx_red;      // pixel data out
  wire [7:0] rx_green;    // pixel data out
  wire [7:0] rx_blue;     // pixel data out
  wire [29:0] rx_sdata;

  dvi_decoder dvi_rx0 (
    //These are input ports
//    .clkin       (clkin),
    .tmdsclk_p   (RX_TMDS[3]),
    .tmdsclk_n   (RX_TMDSB[3]),
    .blue_p      (RX_TMDS[0]),
    .green_p     (RX_TMDS[1]),
    .red_p       (RX_TMDS[2]),
    .blue_n      (RX_TMDSB[0]),
    .green_n     (RX_TMDSB[1]),
    .red_n       (RX_TMDSB[2]),
    .exrst       (0),

    //These are output ports
    .pclk         (clk),
//    .clkx5       (clkx5),
//    .clkx5not    (clkx5not),
    .reset       (reset),
    .hsync       (rx_hsync),
    .vsync       (rx_vsync),
    .de          (rx_de),
    .psalgnerr   (rx_psalgnerr),
    .sdout       (rx_sdata),
    .red         (rx_red),
    .green       (rx_green),
    .blue        (rx_blue)); 

// LVDS output
reg [5:0] Red = 0;
reg [5:0] Blue = 0;
reg [5:0] Green = 0;

video_lvds videoencoder (
    .DotClock(clk), 
    .HSync(rx_hsync), 
    .VSync(rx_vsync), 
    .DataEnable(rx_de), 
    .Red(Red), 
    .Green(Green), 
    .Blue(Blue), 
    .channel1_p(channel1_p), 
    .channel1_n(channel1_n), 
    .channel2_p(channel2_p), 
    .channel2_n(channel2_n), 
    .channel3_p(channel3_p), 
    .channel3_n(channel3_n), 
    .clock_p(clock_p), 
    .clock_n(clock_n)
    );

always @(posedge clk) begin
/*	Red <= 255 - rx_red[7:2];
	Blue <= 255 - rx_blue[7:2];
	Green <= 255 - rx_green[7:2];
*/
  Red <= rx_red[7:2];
  Blue <= rx_blue[7:2];
  Green <= rx_green[7:2];
end

endmodule

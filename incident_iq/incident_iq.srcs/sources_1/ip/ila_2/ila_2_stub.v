// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
// Date        : Sun Mar 29 21:02:24 2026
// Host        : Richard_PC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/richa/Documents/School/ECE532/new-dir/ece532-incidentiq/incident_iq/incident_iq.srcs/sources_1/ip/ila_2/ila_2_stub.v
// Design      : ila_2
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2018.3" *)
module ila_2(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15, probe16, probe17)
/* synthesis syn_black_box black_box_pad_pin="clk,probe0[30:0],probe1[30:0],probe2[30:0],probe3[30:0],probe4[15:0],probe5[15:0],probe6[0:0],probe7[0:0],probe8[0:0],probe9[0:0],probe10[15:0],probe11[18:0],probe12[15:0],probe13[18:0],probe14[15:0],probe15[15:0],probe16[15:0],probe17[15:0]" */;
  input clk;
  input [30:0]probe0;
  input [30:0]probe1;
  input [30:0]probe2;
  input [30:0]probe3;
  input [15:0]probe4;
  input [15:0]probe5;
  input [0:0]probe6;
  input [0:0]probe7;
  input [0:0]probe8;
  input [0:0]probe9;
  input [15:0]probe10;
  input [18:0]probe11;
  input [15:0]probe12;
  input [18:0]probe13;
  input [15:0]probe14;
  input [15:0]probe15;
  input [15:0]probe16;
  input [15:0]probe17;
endmodule

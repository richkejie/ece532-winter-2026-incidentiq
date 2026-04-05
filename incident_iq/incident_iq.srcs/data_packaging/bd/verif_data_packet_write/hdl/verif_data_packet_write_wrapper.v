//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Mon Mar 16 21:36:04 2026
//Host        : Richard_PC running 64-bit major release  (build 9200)
//Command     : generate_target verif_data_packet_write_wrapper.bd
//Design      : verif_data_packet_write_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module verif_data_packet_write_wrapper
   (aresetn,
    data_packet_bram_port_addr,
    data_packet_bram_port_clk,
    data_packet_bram_port_din,
    data_packet_bram_port_dout,
    data_packet_bram_port_en,
    data_packet_bram_port_rst,
    data_packet_bram_port_we,
    sys_clock);
  input aresetn;
  input [31:0]data_packet_bram_port_addr;
  input data_packet_bram_port_clk;
  input [31:0]data_packet_bram_port_din;
  output [31:0]data_packet_bram_port_dout;
  input data_packet_bram_port_en;
  input data_packet_bram_port_rst;
  input [3:0]data_packet_bram_port_we;
  input sys_clock;

  wire aresetn;
  wire [31:0]data_packet_bram_port_addr;
  wire data_packet_bram_port_clk;
  wire [31:0]data_packet_bram_port_din;
  wire [31:0]data_packet_bram_port_dout;
  wire data_packet_bram_port_en;
  wire data_packet_bram_port_rst;
  wire [3:0]data_packet_bram_port_we;
  wire sys_clock;

  verif_data_packet_write verif_data_packet_write_i
       (.aresetn(aresetn),
        .data_packet_bram_port_addr(data_packet_bram_port_addr),
        .data_packet_bram_port_clk(data_packet_bram_port_clk),
        .data_packet_bram_port_din(data_packet_bram_port_din),
        .data_packet_bram_port_dout(data_packet_bram_port_dout),
        .data_packet_bram_port_en(data_packet_bram_port_en),
        .data_packet_bram_port_rst(data_packet_bram_port_rst),
        .data_packet_bram_port_we(data_packet_bram_port_we),
        .sys_clock(sys_clock));
endmodule

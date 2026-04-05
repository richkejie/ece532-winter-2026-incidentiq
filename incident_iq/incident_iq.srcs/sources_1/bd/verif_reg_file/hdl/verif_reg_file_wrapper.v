//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Thu Mar 19 11:18:10 2026
//Host        : Richard_PC running 64-bit major release  (build 9200)
//Command     : generate_target verif_reg_file_wrapper.bd
//Design      : verif_reg_file_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module verif_reg_file_wrapper
   (M_AXI_registers_araddr,
    M_AXI_registers_arprot,
    M_AXI_registers_arready,
    M_AXI_registers_arvalid,
    M_AXI_registers_awaddr,
    M_AXI_registers_awprot,
    M_AXI_registers_awready,
    M_AXI_registers_awvalid,
    M_AXI_registers_bready,
    M_AXI_registers_bresp,
    M_AXI_registers_bvalid,
    M_AXI_registers_rdata,
    M_AXI_registers_rready,
    M_AXI_registers_rresp,
    M_AXI_registers_rvalid,
    M_AXI_registers_wdata,
    M_AXI_registers_wready,
    M_AXI_registers_wstrb,
    M_AXI_registers_wvalid,
    clk_out1,
    cpu_reset_n,
    sys_clock);
  output [31:0]M_AXI_registers_araddr;
  output [2:0]M_AXI_registers_arprot;
  input M_AXI_registers_arready;
  output M_AXI_registers_arvalid;
  output [31:0]M_AXI_registers_awaddr;
  output [2:0]M_AXI_registers_awprot;
  input M_AXI_registers_awready;
  output M_AXI_registers_awvalid;
  output M_AXI_registers_bready;
  input [1:0]M_AXI_registers_bresp;
  input M_AXI_registers_bvalid;
  input [31:0]M_AXI_registers_rdata;
  output M_AXI_registers_rready;
  input [1:0]M_AXI_registers_rresp;
  input M_AXI_registers_rvalid;
  output [31:0]M_AXI_registers_wdata;
  input M_AXI_registers_wready;
  output [3:0]M_AXI_registers_wstrb;
  output M_AXI_registers_wvalid;
  output clk_out1;
  input cpu_reset_n;
  input sys_clock;

  wire [31:0]M_AXI_registers_araddr;
  wire [2:0]M_AXI_registers_arprot;
  wire M_AXI_registers_arready;
  wire M_AXI_registers_arvalid;
  wire [31:0]M_AXI_registers_awaddr;
  wire [2:0]M_AXI_registers_awprot;
  wire M_AXI_registers_awready;
  wire M_AXI_registers_awvalid;
  wire M_AXI_registers_bready;
  wire [1:0]M_AXI_registers_bresp;
  wire M_AXI_registers_bvalid;
  wire [31:0]M_AXI_registers_rdata;
  wire M_AXI_registers_rready;
  wire [1:0]M_AXI_registers_rresp;
  wire M_AXI_registers_rvalid;
  wire [31:0]M_AXI_registers_wdata;
  wire M_AXI_registers_wready;
  wire [3:0]M_AXI_registers_wstrb;
  wire M_AXI_registers_wvalid;
  wire clk_out1;
  wire cpu_reset_n;
  wire sys_clock;

  verif_reg_file verif_reg_file_i
       (.M_AXI_registers_araddr(M_AXI_registers_araddr),
        .M_AXI_registers_arprot(M_AXI_registers_arprot),
        .M_AXI_registers_arready(M_AXI_registers_arready),
        .M_AXI_registers_arvalid(M_AXI_registers_arvalid),
        .M_AXI_registers_awaddr(M_AXI_registers_awaddr),
        .M_AXI_registers_awprot(M_AXI_registers_awprot),
        .M_AXI_registers_awready(M_AXI_registers_awready),
        .M_AXI_registers_awvalid(M_AXI_registers_awvalid),
        .M_AXI_registers_bready(M_AXI_registers_bready),
        .M_AXI_registers_bresp(M_AXI_registers_bresp),
        .M_AXI_registers_bvalid(M_AXI_registers_bvalid),
        .M_AXI_registers_rdata(M_AXI_registers_rdata),
        .M_AXI_registers_rready(M_AXI_registers_rready),
        .M_AXI_registers_rresp(M_AXI_registers_rresp),
        .M_AXI_registers_rvalid(M_AXI_registers_rvalid),
        .M_AXI_registers_wdata(M_AXI_registers_wdata),
        .M_AXI_registers_wready(M_AXI_registers_wready),
        .M_AXI_registers_wstrb(M_AXI_registers_wstrb),
        .M_AXI_registers_wvalid(M_AXI_registers_wvalid),
        .clk_out1(clk_out1),
        .cpu_reset_n(cpu_reset_n),
        .sys_clock(sys_clock));
endmodule

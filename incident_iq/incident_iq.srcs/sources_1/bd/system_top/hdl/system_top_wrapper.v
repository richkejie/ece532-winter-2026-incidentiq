//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Thu Mar 19 11:17:51 2026
//Host        : Richard_PC running 64-bit major release  (build 9200)
//Command     : generate_target system_top_wrapper.bd
//Design      : system_top_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module system_top_wrapper
   (DDR2_0_addr,
    DDR2_0_ba,
    DDR2_0_cas_n,
    DDR2_0_ck_n,
    DDR2_0_ck_p,
    DDR2_0_cke,
    DDR2_0_cs_n,
    DDR2_0_dm,
    DDR2_0_dq,
    DDR2_0_dqs_n,
    DDR2_0_dqs_p,
    DDR2_0_odt,
    DDR2_0_ras_n,
    DDR2_0_we_n,
    GPIO_0_tri_o,
    M_AXI_registers_araddr,
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
    crash_interrupt_in,
    data_packet_bram_port_addr,
    data_packet_bram_port_clk,
    data_packet_bram_port_din,
    data_packet_bram_port_dout,
    data_packet_bram_port_en,
    data_packet_bram_port_rst,
    data_packet_bram_port_we,
    gpio_cd_state_reset_tri_o,
    sd_card_spi_io0_io,
    sd_card_spi_io1_io,
    sd_card_spi_sck_io,
    sd_card_spi_ss_io,
    sys_clock,
    uart_rtl_0_rxd,
    uart_rtl_0_txd,
    usb_uart_rxd,
    usb_uart_txd);
  output [12:0]DDR2_0_addr;
  output [2:0]DDR2_0_ba;
  output DDR2_0_cas_n;
  output [0:0]DDR2_0_ck_n;
  output [0:0]DDR2_0_ck_p;
  output [0:0]DDR2_0_cke;
  output [0:0]DDR2_0_cs_n;
  output [1:0]DDR2_0_dm;
  inout [15:0]DDR2_0_dq;
  inout [1:0]DDR2_0_dqs_n;
  inout [1:0]DDR2_0_dqs_p;
  output [0:0]DDR2_0_odt;
  output DDR2_0_ras_n;
  output DDR2_0_we_n;
  output [0:0]GPIO_0_tri_o;
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
  input [0:0]crash_interrupt_in;
  input [31:0]data_packet_bram_port_addr;
  input data_packet_bram_port_clk;
  input [31:0]data_packet_bram_port_din;
  output [31:0]data_packet_bram_port_dout;
  input data_packet_bram_port_en;
  input data_packet_bram_port_rst;
  input [3:0]data_packet_bram_port_we;
  output [0:0]gpio_cd_state_reset_tri_o;
  inout sd_card_spi_io0_io;
  inout sd_card_spi_io1_io;
  inout sd_card_spi_sck_io;
  inout [0:0]sd_card_spi_ss_io;
  input sys_clock;
  input uart_rtl_0_rxd;
  output uart_rtl_0_txd;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [12:0]DDR2_0_addr;
  wire [2:0]DDR2_0_ba;
  wire DDR2_0_cas_n;
  wire [0:0]DDR2_0_ck_n;
  wire [0:0]DDR2_0_ck_p;
  wire [0:0]DDR2_0_cke;
  wire [0:0]DDR2_0_cs_n;
  wire [1:0]DDR2_0_dm;
  wire [15:0]DDR2_0_dq;
  wire [1:0]DDR2_0_dqs_n;
  wire [1:0]DDR2_0_dqs_p;
  wire [0:0]DDR2_0_odt;
  wire DDR2_0_ras_n;
  wire DDR2_0_we_n;
  wire [0:0]GPIO_0_tri_o;
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
  wire [0:0]crash_interrupt_in;
  wire [31:0]data_packet_bram_port_addr;
  wire data_packet_bram_port_clk;
  wire [31:0]data_packet_bram_port_din;
  wire [31:0]data_packet_bram_port_dout;
  wire data_packet_bram_port_en;
  wire data_packet_bram_port_rst;
  wire [3:0]data_packet_bram_port_we;
  wire [0:0]gpio_cd_state_reset_tri_o;
  wire sd_card_spi_io0_i;
  wire sd_card_spi_io0_io;
  wire sd_card_spi_io0_o;
  wire sd_card_spi_io0_t;
  wire sd_card_spi_io1_i;
  wire sd_card_spi_io1_io;
  wire sd_card_spi_io1_o;
  wire sd_card_spi_io1_t;
  wire sd_card_spi_sck_i;
  wire sd_card_spi_sck_io;
  wire sd_card_spi_sck_o;
  wire sd_card_spi_sck_t;
  wire [0:0]sd_card_spi_ss_i_0;
  wire [0:0]sd_card_spi_ss_io_0;
  wire [0:0]sd_card_spi_ss_o_0;
  wire sd_card_spi_ss_t;
  wire sys_clock;
  wire uart_rtl_0_rxd;
  wire uart_rtl_0_txd;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  IOBUF sd_card_spi_io0_iobuf
       (.I(sd_card_spi_io0_o),
        .IO(sd_card_spi_io0_io),
        .O(sd_card_spi_io0_i),
        .T(sd_card_spi_io0_t));
  IOBUF sd_card_spi_io1_iobuf
       (.I(sd_card_spi_io1_o),
        .IO(sd_card_spi_io1_io),
        .O(sd_card_spi_io1_i),
        .T(sd_card_spi_io1_t));
  IOBUF sd_card_spi_sck_iobuf
       (.I(sd_card_spi_sck_o),
        .IO(sd_card_spi_sck_io),
        .O(sd_card_spi_sck_i),
        .T(sd_card_spi_sck_t));
  IOBUF sd_card_spi_ss_iobuf_0
       (.I(sd_card_spi_ss_o_0),
        .IO(sd_card_spi_ss_io[0]),
        .O(sd_card_spi_ss_i_0),
        .T(sd_card_spi_ss_t));
  system_top system_top_i
       (.DDR2_0_addr(DDR2_0_addr),
        .DDR2_0_ba(DDR2_0_ba),
        .DDR2_0_cas_n(DDR2_0_cas_n),
        .DDR2_0_ck_n(DDR2_0_ck_n),
        .DDR2_0_ck_p(DDR2_0_ck_p),
        .DDR2_0_cke(DDR2_0_cke),
        .DDR2_0_cs_n(DDR2_0_cs_n),
        .DDR2_0_dm(DDR2_0_dm),
        .DDR2_0_dq(DDR2_0_dq),
        .DDR2_0_dqs_n(DDR2_0_dqs_n),
        .DDR2_0_dqs_p(DDR2_0_dqs_p),
        .DDR2_0_odt(DDR2_0_odt),
        .DDR2_0_ras_n(DDR2_0_ras_n),
        .DDR2_0_we_n(DDR2_0_we_n),
        .GPIO_0_tri_o(GPIO_0_tri_o),
        .M_AXI_registers_araddr(M_AXI_registers_araddr),
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
        .crash_interrupt_in(crash_interrupt_in),
        .data_packet_bram_port_addr(data_packet_bram_port_addr),
        .data_packet_bram_port_clk(data_packet_bram_port_clk),
        .data_packet_bram_port_din(data_packet_bram_port_din),
        .data_packet_bram_port_dout(data_packet_bram_port_dout),
        .data_packet_bram_port_en(data_packet_bram_port_en),
        .data_packet_bram_port_rst(data_packet_bram_port_rst),
        .data_packet_bram_port_we(data_packet_bram_port_we),
        .gpio_cd_state_reset_tri_o(gpio_cd_state_reset_tri_o),
        .sd_card_spi_io0_i(sd_card_spi_io0_i),
        .sd_card_spi_io0_o(sd_card_spi_io0_o),
        .sd_card_spi_io0_t(sd_card_spi_io0_t),
        .sd_card_spi_io1_i(sd_card_spi_io1_i),
        .sd_card_spi_io1_o(sd_card_spi_io1_o),
        .sd_card_spi_io1_t(sd_card_spi_io1_t),
        .sd_card_spi_sck_i(sd_card_spi_sck_i),
        .sd_card_spi_sck_o(sd_card_spi_sck_o),
        .sd_card_spi_sck_t(sd_card_spi_sck_t),
        .sd_card_spi_ss_i(sd_card_spi_ss_i_0),
        .sd_card_spi_ss_o(sd_card_spi_ss_o_0),
        .sd_card_spi_ss_t(sd_card_spi_ss_t),
        .sys_clock(sys_clock),
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

//Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
//Date        : Thu Mar 19 11:18:10 2026
//Host        : Richard_PC running 64-bit major release  (build 9200)
//Command     : generate_target verif_reg_file.bd
//Design      : verif_reg_file
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "verif_reg_file,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=verif_reg_file,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=3,numReposBlks=3,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,da_board_cnt=3,da_clkrst_cnt=2,synth_mode=OOC_per_IP}" *) (* HW_HANDOFF = "verif_reg_file.hwdef" *) 
module verif_reg_file
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
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers ARADDR" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI_registers, ADDR_WIDTH 32, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN /clk_wiz_0_clk_out1, DATA_WIDTH 32, FREQ_HZ 100000000, HAS_BRESP 1, HAS_BURST 0, HAS_CACHE 0, HAS_LOCK 0, HAS_PROT 1, HAS_QOS 0, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 1, NUM_READ_OUTSTANDING 2, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 2, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI4LITE, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [31:0]M_AXI_registers_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers ARPROT" *) output [2:0]M_AXI_registers_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers ARREADY" *) input M_AXI_registers_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers ARVALID" *) output M_AXI_registers_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers AWADDR" *) output [31:0]M_AXI_registers_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers AWPROT" *) output [2:0]M_AXI_registers_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers AWREADY" *) input M_AXI_registers_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers AWVALID" *) output M_AXI_registers_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers BREADY" *) output M_AXI_registers_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers BRESP" *) input [1:0]M_AXI_registers_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers BVALID" *) input M_AXI_registers_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers RDATA" *) input [31:0]M_AXI_registers_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers RREADY" *) output M_AXI_registers_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers RRESP" *) input [1:0]M_AXI_registers_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers RVALID" *) input M_AXI_registers_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers WDATA" *) output [31:0]M_AXI_registers_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers WREADY" *) input M_AXI_registers_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers WSTRB" *) output [3:0]M_AXI_registers_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_registers WVALID" *) output M_AXI_registers_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK_OUT1 CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK_OUT1, ASSOCIATED_BUSIF M_AXI_registers, CLK_DOMAIN /clk_wiz_0_clk_out1, FREQ_HZ 100000000, INSERT_VIP 0, PHASE 0.0" *) output clk_out1;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.CPU_RESET_N RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.CPU_RESET_N, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input cpu_reset_n;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.SYS_CLOCK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.SYS_CLOCK, CLK_DOMAIN verif_reg_file_sys_clock, FREQ_HZ 100000000, INSERT_VIP 0, PHASE 0.000" *) input sys_clock;

  wire [31:0]axi_vip_0_M_AXI_ARADDR;
  wire [2:0]axi_vip_0_M_AXI_ARPROT;
  wire axi_vip_0_M_AXI_ARREADY;
  wire axi_vip_0_M_AXI_ARVALID;
  wire [31:0]axi_vip_0_M_AXI_AWADDR;
  wire [2:0]axi_vip_0_M_AXI_AWPROT;
  wire axi_vip_0_M_AXI_AWREADY;
  wire axi_vip_0_M_AXI_AWVALID;
  wire axi_vip_0_M_AXI_BREADY;
  wire [1:0]axi_vip_0_M_AXI_BRESP;
  wire axi_vip_0_M_AXI_BVALID;
  wire [31:0]axi_vip_0_M_AXI_RDATA;
  wire axi_vip_0_M_AXI_RREADY;
  wire [1:0]axi_vip_0_M_AXI_RRESP;
  wire axi_vip_0_M_AXI_RVALID;
  wire [31:0]axi_vip_0_M_AXI_WDATA;
  wire axi_vip_0_M_AXI_WREADY;
  wire [3:0]axi_vip_0_M_AXI_WSTRB;
  wire axi_vip_0_M_AXI_WVALID;
  wire clk_wiz_0_clk_out2;
  wire [0:0]proc_sys_reset_0_peripheral_aresetn;
  wire reset_1;
  wire sys_clock_1;

  assign M_AXI_registers_araddr[31:0] = axi_vip_0_M_AXI_ARADDR;
  assign M_AXI_registers_arprot[2:0] = axi_vip_0_M_AXI_ARPROT;
  assign M_AXI_registers_arvalid = axi_vip_0_M_AXI_ARVALID;
  assign M_AXI_registers_awaddr[31:0] = axi_vip_0_M_AXI_AWADDR;
  assign M_AXI_registers_awprot[2:0] = axi_vip_0_M_AXI_AWPROT;
  assign M_AXI_registers_awvalid = axi_vip_0_M_AXI_AWVALID;
  assign M_AXI_registers_bready = axi_vip_0_M_AXI_BREADY;
  assign M_AXI_registers_rready = axi_vip_0_M_AXI_RREADY;
  assign M_AXI_registers_wdata[31:0] = axi_vip_0_M_AXI_WDATA;
  assign M_AXI_registers_wstrb[3:0] = axi_vip_0_M_AXI_WSTRB;
  assign M_AXI_registers_wvalid = axi_vip_0_M_AXI_WVALID;
  assign axi_vip_0_M_AXI_ARREADY = M_AXI_registers_arready;
  assign axi_vip_0_M_AXI_AWREADY = M_AXI_registers_awready;
  assign axi_vip_0_M_AXI_BRESP = M_AXI_registers_bresp[1:0];
  assign axi_vip_0_M_AXI_BVALID = M_AXI_registers_bvalid;
  assign axi_vip_0_M_AXI_RDATA = M_AXI_registers_rdata[31:0];
  assign axi_vip_0_M_AXI_RRESP = M_AXI_registers_rresp[1:0];
  assign axi_vip_0_M_AXI_RVALID = M_AXI_registers_rvalid;
  assign axi_vip_0_M_AXI_WREADY = M_AXI_registers_wready;
  assign clk_out1 = clk_wiz_0_clk_out2;
  assign reset_1 = cpu_reset_n;
  assign sys_clock_1 = sys_clock;
  verif_reg_file_axi_vip_0_0 axi_vip_0
       (.aclk(clk_wiz_0_clk_out2),
        .aresetn(proc_sys_reset_0_peripheral_aresetn),
        .m_axi_araddr(axi_vip_0_M_AXI_ARADDR),
        .m_axi_arprot(axi_vip_0_M_AXI_ARPROT),
        .m_axi_arready(axi_vip_0_M_AXI_ARREADY),
        .m_axi_arvalid(axi_vip_0_M_AXI_ARVALID),
        .m_axi_awaddr(axi_vip_0_M_AXI_AWADDR),
        .m_axi_awprot(axi_vip_0_M_AXI_AWPROT),
        .m_axi_awready(axi_vip_0_M_AXI_AWREADY),
        .m_axi_awvalid(axi_vip_0_M_AXI_AWVALID),
        .m_axi_bready(axi_vip_0_M_AXI_BREADY),
        .m_axi_bresp(axi_vip_0_M_AXI_BRESP),
        .m_axi_bvalid(axi_vip_0_M_AXI_BVALID),
        .m_axi_rdata(axi_vip_0_M_AXI_RDATA),
        .m_axi_rready(axi_vip_0_M_AXI_RREADY),
        .m_axi_rresp(axi_vip_0_M_AXI_RRESP),
        .m_axi_rvalid(axi_vip_0_M_AXI_RVALID),
        .m_axi_wdata(axi_vip_0_M_AXI_WDATA),
        .m_axi_wready(axi_vip_0_M_AXI_WREADY),
        .m_axi_wstrb(axi_vip_0_M_AXI_WSTRB),
        .m_axi_wvalid(axi_vip_0_M_AXI_WVALID));
  verif_reg_file_clk_wiz_0_0 clk_wiz_0
       (.clk_in1(sys_clock_1),
        .clk_out1(clk_wiz_0_clk_out2),
        .reset(1'b0));
  verif_reg_file_proc_sys_reset_0_0 proc_sys_reset_0
       (.aux_reset_in(1'b1),
        .dcm_locked(1'b1),
        .ext_reset_in(reset_1),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(proc_sys_reset_0_peripheral_aresetn),
        .slowest_sync_clk(clk_wiz_0_clk_out2));
endmodule

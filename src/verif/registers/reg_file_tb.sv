`timescale 1ns / 1ps

// axi vip imports
import axi_vip_pkg::*;
import verif_reg_file_axi_vip_0_0_pkg::*;

module axi_vip_mst_tests();

    // define axi agent
    verif_reg_file_axi_vip_0_0_mst_t       agent;

    // axi related variables
    xil_axi_data_beat                               rd_data[];

    // address offsets --- check address editor
    localparam BASE_ADDR            = 32'h44A0_0000;
    localparam CD_SPEED_THRESH_ADDR = 32'h0000_000C;
    localparam CD_NON_FATAL_ACCEL_THRESH    = 32'h0000_0010;
    localparam CD_FATAL_ACCEL_THRESH        = 32'h0000_0014;
    localparam CD_ANGULAR_SPEED_THRESH      = 32'h0000_0018;

    initial begin
        agent = new("master vip agent", u_verif_system_top.verif_reg_file_i.axi_vip_0.inst.IF);
        agent.start_master();

        wait(reg_file_tb.start_simulation == 1);

        $display("[%0t] Writing 32'h0000_0123 to CD_SPEED_THRESH register", $time);
        write_bram(BASE_ADDR+CD_SPEED_THRESH_ADDR, 32'h0000_0123);
        agent.wait_drivers_idle();
        $display("[%0t] Write complete", $time);

        repeat(10) @(posedge reg_file_tb.clk);
        $finish;

    end

    // write task
    task automatic write_bram(input bit [31:0] addr, input bit [31:0] data);
        axi_transaction wr;
        
        $display("%0t: [TB] Write Start", $time);
        wr = agent.wr_driver.create_transaction("write");
        wr.set_write_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(XIL_AXI_SIZE_4BYTE));
        wr.set_data_block(data);
        agent.wr_driver.send(wr);
    endtask

    // read task
    task automatic read_bram(input bit [31:0] addr, output xil_axi_data_beat data[]);
        axi_transaction rd;

        $display("%0t: [TB] Read Start", $time);
        rd = agent.rd_driver.create_transaction("read");
        rd.set_read_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(XIL_AXI_SIZE_4BYTE));
        
        rd.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
        agent.rd_driver.send(rd);
        agent.rd_driver.wait_rsp(rd);

        data = new[rd.get_len()+1];
        for ( xil_axi_uint beat=0; beat < rd.get_len()+1; beat++ ) begin
            data[beat] = rd.get_data_beat(beat);
        end

        $display("%0t: [TB] Read Complete, data = %0x", $time, data[0]);
    endtask

endmodule


module reg_file_tb();

    parameter CLK_PERIOD = 10;
    parameter RESET_CYCLES = 20;

    logic clk;
    logic arst_n;

    logic system_top_clk_out1;

    logic M_AXI_registers_s_axil_awready;
    logic M_AXI_registers_s_axil_awvalid;
    logic [31:0] M_AXI_registers_s_axil_awaddr;
    logic [2:0] M_AXI_registers_s_axil_awprot;
    logic M_AXI_registers_s_axil_wready;
    logic M_AXI_registers_s_axil_wvalid;
    logic [31:0] M_AXI_registers_s_axil_wdata;
    logic [3:0] M_AXI_registers_s_axil_wstrb;
    logic M_AXI_registers_s_axil_bready;
    logic M_AXI_registers_s_axil_bvalid;
    logic [1:0] M_AXI_registers_s_axil_bresp;
    logic M_AXI_registers_s_axil_arready;
    logic M_AXI_registers_s_axil_arvalid;
    logic [3:0] M_AXI_registers_s_axil_araddr;
    logic [2:0] M_AXI_registers_s_axil_arprot;
    logic M_AXI_registers_s_axil_rready;
    logic M_AXI_registers_s_axil_rvalid;
    logic [31:0] M_AXI_registers_s_axil_rdata;
    logic [1:0] M_AXI_registers_s_axil_rresp;

    registers_pkg::registers__in_t whwif_in;
    registers_pkg::registers__out_t whwif_out;

    logic [31:0] converted_M_AXI_registers_s_axil_awaddr;

    registers u_reg_file(
        .clk(system_top_clk_out1),
        .arst_n(arst_n),
        .s_axil_awready(M_AXI_registers_s_axil_awready),
        .s_axil_awvalid(M_AXI_registers_s_axil_awvalid),
        .s_axil_awaddr(converted_M_AXI_registers_s_axil_awaddr),
        .s_axil_awprot(M_AXI_registers_s_axil_awprot),
        .s_axil_wready(M_AXI_registers_s_axil_wready),
        .s_axil_wvalid(M_AXI_registers_s_axil_wvalid),
        .s_axil_wdata(M_AXI_registers_s_axil_wdata),
        .s_axil_wstrb(M_AXI_registers_s_axil_wstrb),
        .s_axil_bready(M_AXI_registers_s_axil_bready),
        .s_axil_bvalid(M_AXI_registers_s_axil_bvalid),
        .s_axil_bresp(M_AXI_registers_s_axil_bresp),
        .s_axil_arready(M_AXI_registers_s_axil_arready),
        .s_axil_arvalid(M_AXI_registers_s_axil_arvalid),
        .s_axil_araddr(M_AXI_registers_s_axil_araddr),
        .s_axil_arprot(M_AXI_registers_s_axil_arprot),
        .s_axil_rready(M_AXI_registers_s_axil_rready),
        .s_axil_rvalid(M_AXI_registers_s_axil_rvalid),
        .s_axil_rdata(M_AXI_registers_s_axil_rdata),
        .s_axil_rresp(M_AXI_registers_s_axil_rresp),
        .hwif_in(whwif_in),
        .hwif_out(whwif_out)
    );

    verif_reg_file_wrapper u_verif_system_top(
        .sys_clock(clk),
        .cpu_reset_n(arst_n),
        .clk_out1(system_top_clk_out1),
        .M_AXI_registers_araddr(M_AXI_registers_s_axil_araddr),
        .M_AXI_registers_arprot(M_AXI_registers_s_axil_arprot),
        .M_AXI_registers_arready(M_AXI_registers_s_axil_arready),
        .M_AXI_registers_arvalid(M_AXI_registers_s_axil_arvalid),
        .M_AXI_registers_awaddr(M_AXI_registers_s_axil_awaddr),
        .M_AXI_registers_awprot(M_AXI_registers_s_axil_awprot),
        .M_AXI_registers_awready(M_AXI_registers_s_axil_awready),
        .M_AXI_registers_awvalid(M_AXI_registers_s_axil_awvalid),
        .M_AXI_registers_bready(M_AXI_registers_s_axil_bready),
        .M_AXI_registers_bresp(M_AXI_registers_s_axil_bresp),
        .M_AXI_registers_bvalid(M_AXI_registers_s_axil_bvalid),
        .M_AXI_registers_rdata(M_AXI_registers_s_axil_rdata),
        .M_AXI_registers_rready(M_AXI_registers_s_axil_rready),
        .M_AXI_registers_rresp(M_AXI_registers_s_axil_rresp),
        .M_AXI_registers_rvalid(M_AXI_registers_s_axil_rvalid),
        .M_AXI_registers_wdata(M_AXI_registers_s_axil_wdata),
        .M_AXI_registers_wready(M_AXI_registers_s_axil_wready),
        .M_AXI_registers_wstrb(M_AXI_registers_s_axil_wstrb),
        .M_AXI_registers_wvalid(M_AXI_registers_s_axil_wvalid)
    );

    assign converted_M_AXI_registers_s_axil_awaddr = { 16'b0, M_AXI_registers_s_axil_awaddr[15:0] };

    // clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // apply reset cleanly for 5 cycles
    task apply_reset;
        $display("%0t: apply reset", $time);
        arst_n = 0;
        repeat (RESET_CYCLES) @(posedge clk);
        arst_n = 1;
        repeat (RESET_CYCLES) @(posedge clk);
    endtask

    // --------------main simulation code--------------
    integer start_simulation = 0;
    integer simulation_done = 0;
    
    initial begin
        apply_reset();
        start_simulation = 1;
    end

    axi_vip_mst_tests mst();


endmodule


`timescale 1ns / 1ps

// this is the main tb for the data packager

// axi vip imports
import axi_vip_pkg::*;
import verif_data_packet_write_axi_vip_0_0_pkg::*;

module axi_vip_mst_tests();

    // define axi agent
    verif_data_packet_write_axi_vip_0_0_mst_t       agent;

    // axi related variables
    xil_axi_data_beat                               rd_data[];

    // address offsets --- check address editor
    localparam DATA_PACKET_BASE_ADDR        = 32'hC000_0000;
    localparam TB_TEST_ADDR                 = DATA_PACKET_BASE_ADDR + 4;

    integer read_done = 0;

    integer i;

    initial begin
        // create and start agent
        agent = new("master vip agent", u_verif_system_top.verif_data_packet_write_i.axi_vip_0.inst.IF);
        agent.start_master();

        wait(data_packet_write_tb.start_simulation == 1);

        data_packet_write_tb.wait_data_revc();
        $display("[%0t] TC1: data succesfully received!", $time);

        $display("[%0t] TC1: reading back data from buffer", $time);
        for (i = 0; i < 10; i++) begin
            $display("[%0t] TC1: reading from address 32'h(%h)", $time, DATA_PACKET_BASE_ADDR+i*4);
            
            read_bram(32'(DATA_PACKET_BASE_ADDR + (i*4)), rd_data);

            $display("[%0t] TC1: rdata: %0h", $time, rd_data[0]);
            data_packet_write_tb.advance_read_ptr();
        end

        @(posedge data_packet_write_tb.clk);
        read_done = 1;

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

module data_packet_write_tb();

    parameter CLK_PERIOD = 10;
    parameter RESET_CYCLES = 20;
    parameter GPS_SENTENCE_BITS = 1024;
    parameter SENTENCE_BITS = GPS_SENTENCE_BITS;

    logic clk;
    logic arst_n;

    // inputs to data_packager
    logic           i_gps_valid, i_accel_valid, i_gyro_valid;
    logic [GPS_SENTENCE_BITS-1:0] i_gps_sentence;
    logic [15:0]    i_accel_z, i_accel_y, i_accel_x;
    logic [15:0]    i_gyro_z, i_gyro_y, i_gyro_x;

    logic           o_data_recv;
    logic [10*32-1:0]    o_packet;
    logic           o_packet_valid;
    logic [31:0]    o_data_packet_bram_addr;
    logic [31:0]    o_data_packet_bram_din;
    logic [3:0]     o_data_packet_bram_we;
    logic           o_data_packet_bram_en;

    logic [10:0]    o_data_packet_bram_write_ptr;
    logic           o_data_packet_bram_status_empty;
    logic           o_data_packet_bram_status_full;
    logic [10:0]    i_data_packet_bram_read_ptr;
    
    data_packager #(
        .GPS_SENTENCE_BITS(1024)
    ) u_data_packager(
        .clk(clk),
        .arst_n(arst_n),
        .i_gps_valid(i_gps_valid),
        .i_accel_valid(i_accel_valid),
        .i_gyro_valid(i_gyro_valid),
        .i_gps_sentence(i_gps_sentence),
        .i_accel_z(i_accel_z),
        .i_accel_y(i_accel_y),
        .i_accel_x(i_accel_x),
        .i_gyro_z(i_gyro_z),
        .i_gyro_y(i_gyro_y),
        .i_gyro_x(i_gyro_x),

        .o_data_recv(o_data_recv),
        .o_packet(o_packet),
        .o_packet_valid(o_packet_valid),
        .o_data_packet_bram_addr(o_data_packet_bram_addr),
        .o_data_packet_bram_din(o_data_packet_bram_din),
        .o_data_packet_bram_we(o_data_packet_bram_we),
        .o_data_packet_bram_en(o_data_packet_bram_en),

        .o_data_packet_bram_write_ptr(o_data_packet_bram_write_ptr),
        .o_data_packet_bram_status_empty(o_data_packet_bram_status_empty),
        .o_data_packet_bram_status_full(o_data_packet_bram_status_full),
        .i_data_packet_bram_read_ptr(i_data_packet_bram_read_ptr),

        .o_cd_accel_z(),
        .o_cd_accel_y(),
        .o_cd_accel_x(),
        .o_cd_gyro_z(),
        .o_cd_gyro_y(),
        .o_cd_gyro_x(),
        .o_cd_gps_ground_speed()
    );
    
    verif_data_packet_write_wrapper u_verif_system_top(
        .aresetn(arst_n),
        .data_packet_bram_port_addr(o_data_packet_bram_addr),
        .data_packet_bram_port_clk(clk),
        .data_packet_bram_port_din(o_data_packet_bram_din),
        .data_packet_bram_port_dout(),  // not used
        .data_packet_bram_port_en(o_data_packet_bram_en),
        .data_packet_bram_port_rst(arst_n),
        .data_packet_bram_port_we(o_data_packet_bram_we),
        .sys_clock(clk)
    );

    // clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // intialize signals
    task init;
        i_gps_valid = 0; i_accel_valid = 0; i_gyro_valid = 0;
        i_accel_z = 16'b0; i_accel_y = 16'b0; i_accel_x = 16'b0;
        i_gyro_z = 16'b0; i_gyro_y = 16'b0; i_gyro_x = 16'b0;
        i_data_packet_bram_read_ptr = 11'b0;
    endtask

    // apply reset cleanly for 5 cycles
    task apply_reset;
        $display("%0t: apply reset", $time);
        arst_n = 0;
        repeat (RESET_CYCLES) @(posedge clk);
        arst_n = 1;
        repeat (RESET_CYCLES) @(posedge clk);
    endtask

    // send a sensor sample
    task send_sample(
        input [GPS_SENTENCE_BITS-1:0] gps_sentence,
        input [11:0] accel_z,
        input [11:0] accel_y,
        input [11:0] accel_x,
        input [15:0] gyro_z,
        input [15:0] gyro_y,
        input [15:0] gyro_x
    );
        begin
            @(posedge clk);
            i_gps_sentence      <= gps_sentence;
            i_accel_z           <= { {4{accel_z[11]}}, accel_z };
            i_accel_y           <= { {4{accel_y[11]}}, accel_y };
            i_accel_x           <= { {4{accel_x[11]}}, accel_x };
            i_gyro_z            <= gyro_z;
            i_gyro_y            <= gyro_y;
            i_gyro_x            <= gyro_x;
            @(posedge clk);
            i_gps_valid     <= 1'b1;
            i_accel_valid   <= 1'b1;
            i_gyro_valid    <= 1'b1;
            @(posedge clk);
            i_gps_valid     <= 1'b0;
            i_accel_valid   <= 1'b0;
            i_gyro_valid    <= 1'b0;
        end
    endtask

    task wait_data_revc;
        wait(o_data_recv == 1'b1);
    endtask

    task advance_read_ptr;
        @(posedge clk);
        i_data_packet_bram_read_ptr     <= i_data_packet_bram_read_ptr + 11'd4;
    endtask

    // convert sentence to bits
    function logic [SENTENCE_BITS-1:0] string_to_bits(input string s);
        automatic logic [SENTENCE_BITS-1:0] tmp = '0;
        for (int i = 0; i < s.len() && i < 128; i++) begin
            tmp[8*(127-i) +: 8] = s[i];
        end
        return tmp;
    endfunction

    // --------------main simulation code--------------
    integer start_simulation = 0;
    integer simulation_done = 0;
    
    initial begin
        init();
        apply_reset();
        start_simulation = 1;
    end
    
    axi_vip_mst_tests mst();

    logic [SENTENCE_BITS-1:0] sentence;
    string test_sentence;
    initial begin
        wait(start_simulation == 1);

        $display("[%0t] TC1: send 1 packet", $time);
        // for some reason the uart gps extractor module outputs a reversed ASCII sentence
        test_sentence = "55*A,W,50.3,604062,84.561,23.1,E,0344.61021,N,0521.7032,A,301.159460,CMRPG$";
        sentence = string_to_bits(test_sentence);
        send_sample(
            sentence,
            12'h0AB,
            12'h872,
            12'h43E,
            16'hF234,
            16'h0065,
            16'h2390
        );

        wait(mst.read_done == 1);

        repeat(10) @(posedge clk);
        $finish;
    end

    // probe each 32 bit word of packet
    logic [31:0] packet_probe [0:9];
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : packet_slice_logic
            assign packet_probe[i] = o_packet[(i*32) +: 32];
        end
    endgenerate

    
endmodule

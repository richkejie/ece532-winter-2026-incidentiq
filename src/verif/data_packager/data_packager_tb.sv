`timescale 1ns / 1ps

module data_packager_tb();

    parameter CLK_PERIOD = 10; // 100 MHz clock
    parameter RESET_CYCLES = 5;


    logic clk;
    logic rst;

    // inputs to data_packager
    logic           in_valid;
    logic [15:0]    i_gps;
    logic [15:0]    i_accel;
    logic [15:0]    i_gyro;
    logic [7:0]     i_temp;
    logic [7:0]     i_delta;

    // outputs from data_packager
    logic [63:0]    o_packet;
    logic           o_packet_valid;
    logic [31:0]    o_data_packet_bram_addr;
    logic [31:0]    o_data_packet_bram_din;
    logic [3:0]     o_data_packet_bram_we;
    logic           o_data_packet_bram_en;

    // expected
    logic [63:0]    expected_packet;

    data_packager dut (
        .*  // connect all matching signal names
    );

    // clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // intialize signals
    task init;
        in_valid = 0;
        i_gps = 0; i_accel = 0; i_gyro = 0; i_temp = 0; i_delta = 0;
    endtask

    // apply reset cleanly for 5 cycles
    task apply_reset;
        $display("%0t: apply reset", $time);
        rst = 1;
        repeat (RESET_CYCLES) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);
    endtask

    // send a sensor sample
    task send_sample(
        input [15:0] gps,
        input [15:0] accel,
        input [15:0] gyro,
        input [7:0] temp,
        input [7:0] delta
    );
        begin
            @(posedge clk);
            in_valid    <= 1'b1;
            i_gps       <= gps;
            i_accel     <= accel;
            i_gyro      <= gyro;
            i_temp      <= temp;
            i_delta     <= delta;
            @(posedge clk);
            in_valid    <= 1'b0;
        end
    endtask

    // --------------main simulation code--------------
    integer start_simulation = 0;
    integer simulation_done = 0;
    
    
    initial begin
        init();
        apply_reset();
        start_simulation = 1;
    end

    // #### driver ####
    initial begin
        wait (start_simulation == 1);

        // Test Case 1: Send a basic packet
        $display("%0t: TC1: Sending Sample 1...", $time);
        send_sample(16'hAAAA, 16'hBBBB, 16'hCCCC, 8'hDD, 8'hEE);

        // Test Case 2: Send another packet immediately
        $display("%0t: TC2: Sending Sample 2...", $time);
        send_sample(16'h1111, 2222, 16'h3333, 8'h44, 8'h55);

        // Test Case 3: Random data
        repeat (5) @(posedge clk);
        $display("%0t: TC3: Sending Sample 3 (Random)...", $time);
        send_sample($urandom, $urandom, $urandom, $urandom, $urandom);

        repeat(20) @(posedge clk);
        $finish;
    end

    // #### monitor ####
    always @(posedge clk) begin
        if (o_data_packet_bram_we == 4'b1111) begin
            $display("%0t: BRAM WRITE: Addr: %0d, Data: %h", $time, o_data_packet_bram_addr, o_data_packet_bram_din);
            
            // Check if BRAM data matches the lower 32 bits of the current o_packet
            if (o_data_packet_bram_din !== o_packet[31:0]) begin
                 $display("ERROR: BRAM Data mismatch with lower packet bits!");
            end
        end
    end

    // #### scoreboard ####
    // The data_packager adds 1 clock of latency for o_packet
    // The bram_writer adds 1 more clock of latency for BRAM signals
    
    always @(posedge clk) begin
        if (o_packet_valid) begin
            expected_packet = {i_gps, i_accel, i_gyro, i_temp, i_delta};
            
            // Checking the 64-bit output
            if (o_packet !== expected_packet) begin
                $display("%0t: ERROR: Packet Mismatch! Expected: %h, Got: %h", $time, expected_packet, o_packet);
            end else begin
                $display("%0t: SUCCESS: Packet Match: %h", $time, o_packet);
            end
        end
    end


endmodule

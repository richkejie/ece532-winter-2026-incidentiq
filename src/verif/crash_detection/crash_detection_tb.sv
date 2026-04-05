`timescale 1ns / 1ps

module crash_detection_tb();

    parameter HISTORY_LEN = 16;

    parameter CLK_PERIOD = 10; // 100 MHz clock
    parameter RESET_CYCLES = 5;


    logic clk;
    logic arst_n;

    // inputs to crash_detection
    logic           i_state_rst;
    logic           i_sensors_valid;

    logic [31:0]    i_gps_ground_speed;

    logic [15:0]    i_accel_z, i_accel_y, i_accel_x;
    logic [15:0]    i_gyro_z, i_gyro_y, i_gyro_x;

    logic [31:0]    ireg_speed_threshold                = 32'd20; // 20 * 100 knots
    logic [31:0]    ireg_non_fatal_accel_threshold      = 32'd125; // ~0.5G
    logic [31:0]    ireg_fatal_accel_threshold          = 32'd125; // ~0.5G
    logic [31:0]    ireg_angular_speed_threshold        = 32'd8000; // ~60dps
    logic           ireg_cd_en;

    // outputs from crash_detection
    logic [1:0]     o_state;
    logic           o_non_fatal_intr;
    logic           o_fatal_intr;

    crash_detection #(
        .HISTORY_LEN(HISTORY_LEN)
    ) dut (
        .*  // connect all matching signal names
    );

    // clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // intialize signals
    task init;
        i_state_rst = 0;
        i_sensors_valid = 0;
        ireg_cd_en = 0;
        i_gps_ground_speed = 0;
        i_accel_z = 0; i_accel_y = 0; i_accel_x = 0;
        i_gyro_z = 0; i_gyro_y = 0; i_gyro_x = 0;
    endtask

    // apply reset cleanly for 5 cycles
    task apply_reset;
        $display("%0t: apply reset", $time);
        arst_n = 0;
        repeat (RESET_CYCLES) @(posedge clk);
        arst_n = 1;
        repeat (2) @(posedge clk);
    endtask

    task reset_state;
        $display("%0t: reset state", $time);
        @(posedge clk);
        i_state_rst = 1;
        @(posedge clk);
        i_state_rst = 0;
    endtask

    task enable_cd;
        $display("%0t: enable crash detection", $time);
        @(posedge clk);
        ireg_cd_en = 1;
        @(posedge clk);
    endtask

    task disable_cd;
        @(posedge clk);
        ireg_cd_en = 0;
        @(posedge clk);
    endtask

    // send a sensor sample
    task send_sample(
        input [31:0] gps_ground_speed,
        input [15:0] accel_z,
        input [15:0] accel_y,
        input [15:0] accel_x,
        input [15:0] gyro_z,
        input [15:0] gyro_y,
        input [15:0] gyro_x
    );
        begin
            @(posedge clk);
            i_sensors_valid = 1'b1;
            i_gps_ground_speed = gps_ground_speed;
            i_accel_z = accel_z; i_accel_y = accel_y; i_accel_x = accel_x;
            i_gyro_z = gyro_z; i_gyro_y = gyro_y; i_gyro_x = gyro_x;
            @(posedge clk);
            i_sensors_valid = 1'b0;
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

        // Test Case 1: Normal Driving (Safe State)
        // gps increases, but accel/gyro remain low
        enable_cd();
        $display("%0t: TC1: Normal Driving", $time);
        for (int i = 0; i < 20; i++) begin
            send_sample(0, -800, -800, -800, 1, 1, 1);
        end
        #100;

        reset_state();

        simulation_done = 1;
    end

    // #### monitor ####
    initial begin
        wait (start_simulation == 1);
        $display("%0t: --- Starting Simulation ---", $time);
        $monitor("%0t | State:%b | Non-Fatal:%b | Fatal:%b", 
              $time, o_state, o_non_fatal_intr, o_fatal_intr);
    end

    // // Simple logging assertion
     always @(posedge o_fatal_intr) 
         $display("%0t [ASSERTION] Fatal Crash Detected!", $time);

     always @(posedge o_non_fatal_intr) 
         $display("%0t [ASSERTION] Non-Fatal Crash Detected!", $time);

    // #### end sim ####
    initial begin
        wait (simulation_done == 1);
        repeat (5) @(posedge clk); // wait 5 cycles before ending
        $display("Simulation finished at time %0t", $time);
        $finish;
    end


endmodule

`timescale 1ns / 1ps

module max_norm_3_axes_tb();

    parameter CLK_PERIOD = 10; // 100 MHz clock

    logic [15:0]    i_accel_z,i_accel_y,i_accel_x;
    
    logic [15:0]    i_gyro_z,i_gyro_y,i_gyro_x;
    
    logic [11:0] accel_max_norm;
    logic [15:0] gyro_max_norm;

    max_norm_3_axes #(
        .DATA_LEN(16),
        .DATA_MSB(12)
    ) u_accel_max_norm (
        .i_data_x(i_accel_x),
        .i_data_y(i_accel_y),
        .i_data_z(i_accel_z),
        .o_data_max_norm(accel_max_norm)
    );
    
    max_norm_3_axes #(
        .DATA_LEN(16),
        .DATA_MSB(16)
    ) u_gyro_max_norm (
        .i_data_x(i_gyro_x),
        .i_data_y(i_gyro_y),
        .i_data_z(i_gyro_z),
        .o_data_max_norm(gyro_max_norm)
    );
    
    logic clk;
    // clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer accel_tests_done = 0;
    integer gyro_tests_done = 0;

    // gyro
    initial begin
        // all positive
        i_gyro_z = 16'h0001;
        i_gyro_y = 16'h0003;
        i_gyro_x = 16'h0007;
        
        repeat(10)@(posedge clk);
        // 1 negative number
        i_gyro_z = 16'hf009;
        i_gyro_y = 16'h0008;
        i_gyro_x = 16'h0004;
        
        repeat(10)@(posedge clk);
        // 2 negative numebrs
        i_gyro_z = 16'hf082;
        i_gyro_y = 16'hf173;
        i_gyro_x = 16'h0569;
        
        repeat(10)@(posedge clk);
        // all negative
        i_gyro_z = 16'hf999;
        i_gyro_y = 16'hf888;
        i_gyro_x = 16'hffff;
        
        accel_tests_done = 1;
    
    end

    // accel
    initial begin
        // all positive
        i_accel_z = 16'h0001;
        i_accel_y = 16'h0003;
        i_accel_x = 16'h0007;
        
        repeat(10)@(posedge clk);
        // 1 negative number
        i_accel_z = 16'hf009;
        i_accel_y = 16'h0008;
        i_accel_x = 16'h0004;
        
        repeat(10)@(posedge clk);
        // 2 negative numebrs
        i_accel_z = 16'hf082;
        i_accel_y = 16'hf173;
        i_accel_x = 16'h0569;
        
        repeat(10)@(posedge clk);
        // all negative
        i_accel_z = 16'hf999;
        i_accel_y = 16'hf888;
        i_accel_x = 16'hf777;
        
        gyro_tests_done = 1;    
    end
    
    initial begin
        wait ((accel_tests_done == 1) & (gyro_tests_done == 1));
        repeat(10)@(posedge clk);
        $finish;
    end

endmodule
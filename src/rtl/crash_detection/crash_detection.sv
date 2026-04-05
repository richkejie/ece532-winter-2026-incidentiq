`timescale 1ns / 1ps

module crash_detection #(
        parameter int HISTORY_LEN = 16 // must be a power of 2
    )(
        input   logic           clk,
        input   logic           arst_n,
        
        input   logic           i_state_rst,
        
        input   logic           i_sensors_valid,
        
        input   logic [31:0]    i_gps_ground_speed,
        
        input   logic [15:0]    i_accel_z,
        input   logic [15:0]    i_accel_y,
        input   logic [15:0]    i_accel_x,
        
        input   logic [15:0]    i_gyro_z,
        input   logic [15:0]    i_gyro_y,
        input   logic [15:0]    i_gyro_x,
        
        // config registers
        input   logic [31:0]    ireg_speed_threshold,
        input   logic [31:0]    ireg_non_fatal_accel_threshold,
        input   logic [31:0]    ireg_fatal_accel_threshold,
        input   logic [31:0]    ireg_angular_speed_threshold,
        input   logic           ireg_cd_en,
        
        output  logic [1:0]     o_state,
        output  logic           o_non_fatal_intr,
        output  logic           o_fatal_intr
    );

    // --------------- Sensor Data ---------------
    
    // compute max norm for acceleration
    logic [11:0] accel_max_norm;
    logic [15:0] next_accel;
    
    max_norm_3_axes #(
        .DATA_LEN(16),
        .DATA_MSB(12)
    ) u_accel_max_norm (
        .i_data_x(i_accel_x),
        .i_data_y(i_accel_y),
        .i_data_z(i_accel_z),
        .o_data_max_norm(accel_max_norm)
    );
    assign next_accel = {4'b0, accel_max_norm};
    
    // compute max norm for gyro angular rate
    logic [15:0] gyro_max_norm;
    logic [15:0] next_gyro;
    
    max_norm_3_axes #(
        .DATA_LEN(16),
        .DATA_MSB(16)
    ) u_gyro_max_norm (
        .i_data_x(i_gyro_x),
        .i_data_y(i_gyro_y),
        .i_data_z(i_gyro_z),
        .o_data_max_norm(gyro_max_norm)
    );
    assign next_gyro = gyro_max_norm;
    

    // shift registers to keep history
    logic [HISTORY_LEN-1:0][15:0] shift_accel, shift_gyro, shift_gps;
    
    always_ff @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            shift_gps       <= '0;
            shift_accel     <= '0;
            shift_gyro      <= '0;
        end else if (ireg_cd_en) begin
            if (i_state_rst) begin
                shift_gps       <= '0;
                shift_accel     <= '0;
                shift_gyro      <= '0;
            end else if (i_sensors_valid) begin
                shift_gps       <= {shift_gps[HISTORY_LEN-1-1:0],i_gps_ground_speed};
                shift_accel     <= {shift_accel[HISTORY_LEN-1-1:0],next_accel};
                shift_gyro      <= {shift_gyro[HISTORY_LEN-1-1:0],next_gyro};
            end // otherwise keeps the same data
        end else begin
            shift_gps       <= '0;
            shift_accel     <= '0;
            shift_gyro      <= '0;
        end
    end
    
    // running sums of history
    // pure combinational add --- may not meet timing...
    logic [HISTORY_LEN-1+3:0] accel_running_sum, gyro_running_sum, gps_running_sum;
    
    always_comb begin
        accel_running_sum = '0;
        gyro_running_sum = '0;
        gps_running_sum = '0;
        for (int i =0; i <= HISTORY_LEN-1; i++) begin
            accel_running_sum = accel_running_sum + shift_accel[i];
            gyro_running_sum = gyro_running_sum + shift_gyro[i];
            gps_running_sum = gps_running_sum + shift_gps[i];
        end
    end
    
    // compute average values from running sum and history length
    logic [HISTORY_LEN-1:0] avg_accel, avg_gyro, avg_gps;
    logic [HISTORY_LEN-1:0] avg_accel_d, avg_gyro_d, avg_gps_d;
    assign avg_accel = accel_running_sum >> $clog2(HISTORY_LEN);
    assign avg_gyro = gyro_running_sum >> $clog2(HISTORY_LEN);
    assign avg_gps = gps_running_sum >> $clog2(HISTORY_LEN);
    always_ff @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            avg_accel_d             <= '0;
            avg_gyro_d      <= '0;
            avg_gps_d    <= '0;
        end else if (ireg_cd_en) begin
            if (i_state_rst) begin
                avg_accel_d             <= '0;
                avg_gyro_d      <= '0;
                avg_gps_d    <= '0;
            end else begin
                avg_accel_d             <= avg_accel;
                avg_gyro_d        <= avg_gyro;
                avg_gps_d      <= avg_gps;
            end
        end else begin
            avg_accel_d             <= '0;
            avg_gyro_d      <= '0;
            avg_gps_d    <= '0;
        end
    end
    

    logic [HISTORY_LEN-1:0] avg_speed;
    assign avg_speed = avg_gps_d;

    // --------------- FSM ---------------
    typedef enum logic [1:0] {
        SAFE                = 2'b00,
        NON_FATAL           = 2'b01,
        FATAL               = 2'b10
    } crash_state_t;
    
    crash_state_t crash_state, crash_state_next;
    
    always_ff @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            crash_state         <= SAFE;
        end else if (ireg_cd_en) begin
            if (i_state_rst) begin
                crash_state     <= SAFE;
            end else begin
                crash_state     <= crash_state_next;
            end
        end else begin
            crash_state         <= SAFE;
        end
    end
    
    logic gyro_thresh_crossed, fatal_accel_thresh_crossed, non_fatal_accel_thresh_cross;
    assign gyro_thresh_crossed = (avg_gyro_d > ireg_angular_speed_threshold);
    assign fatal_accel_thresh_crossed = (avg_accel_d > ireg_fatal_accel_threshold);
    assign non_fatal_accel_thresh_cross = (avg_accel_d > ireg_non_fatal_accel_threshold);
    
    logic gyro_thresh_crossed_d, fatal_accel_thresh_crossed_d, non_fatal_accel_thresh_cross_d;
    always_ff @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            gyro_thresh_crossed_d             <= 1'b0;
            fatal_accel_thresh_crossed_d      <= 1'b0;
            non_fatal_accel_thresh_cross_d    <= 1'b0;
        end else if (ireg_cd_en) begin
            if (i_state_rst) begin
                gyro_thresh_crossed_d             <= 1'b0;
                fatal_accel_thresh_crossed_d      <= 1'b0;
                non_fatal_accel_thresh_cross_d    <= 1'b0;
            end else begin
                gyro_thresh_crossed_d             <= gyro_thresh_crossed;
                fatal_accel_thresh_crossed_d        <= fatal_accel_thresh_crossed;
                non_fatal_accel_thresh_cross_d      <= non_fatal_accel_thresh_cross;
            end
        end else begin
            gyro_thresh_crossed_d             <= 1'b0;
            fatal_accel_thresh_crossed_d      <= 1'b0;
            non_fatal_accel_thresh_cross_d    <= 1'b0;
        end
    end
   
    logic crash_triggered;
    logic crash_condition;
    assign crash_condition = (gyro_thresh_crossed_d | fatal_accel_thresh_crossed_d | non_fatal_accel_thresh_cross_d);
    always_ff @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            crash_triggered     <= 1'b0;
        end else if (ireg_cd_en) begin
            if (i_state_rst) begin
                crash_triggered <= 1'b0;
            end else if (crash_condition) begin
                crash_triggered <= 1'b1;
            end else begin
                crash_triggered <= 1'b0;
            end
        end else begin
            crash_triggered     <= 1'b0;
        end
    end
    
    always_comb begin
        crash_state_next = crash_state;
        
        case(crash_state)
            SAFE: begin
                crash_state_next = SAFE;
                if (crash_triggered) begin
                    crash_state_next = NON_FATAL;
                end
            end
            
            NON_FATAL: begin
                crash_state_next = NON_FATAL;
                if (i_state_rst) crash_state_next = SAFE;
            end
            
            FATAL: begin
                crash_state_next = FATAL;
                if (i_state_rst) crash_state_next = SAFE;
            end
            
            default: crash_state_next = SAFE;
        endcase
    end

    // --------------- Outputs ---------------
    assign o_state = crash_state;
    assign o_non_fatal_intr = (crash_state == NON_FATAL);
    assign o_fatal_intr = (crash_state == FATAL);


    // ILA
    ila_2 u_ila(
        .clk(clk),
        .probe0(ireg_speed_threshold),
        .probe1(ireg_non_fatal_accel_threshold),
        .probe2(ireg_fatal_accel_threshold),
        .probe3(ireg_angular_speed_threshold),
        .probe4(avg_accel_d),
        .probe5(avg_gyro_d),
        .probe6(gyro_thresh_crossed_d),
        .probe7(fatal_accel_thresh_crossed_d),
        .probe8(non_fatal_accel_thresh_cross_d),
        .probe9(crash_triggered),
        .probe10(next_accel),
        .probe11(accel_running_sum),
        .probe12(next_gyro),
        .probe13(gyro_running_sum),
        .probe14(i_accel_x),
        .probe15(i_accel_y),
        .probe16(i_accel_z),
        .probe17(accel_max_norm)
    );

endmodule

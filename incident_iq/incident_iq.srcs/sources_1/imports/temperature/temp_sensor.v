`timescale 1ns/1ps

module temp_sensor_driver (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        cmd_start,
    input  wire        rw,
    input  wire [2:0]  high_level_cmd,
    input  wire [15:0] cmd_value,

    output reg         cmd_done,
    output reg  [15:0] read_data,
    output reg         error,
    inout wire        scl, 
    inout  wire        sda,
    output wire        busy,
    output wire [3:0]  master_state,
    output reg         start,
    output reg         start_latched,
    output reg         cmd_start_latched,
    output wire [3:0]  bit_cnt,
    output wire [4:0]  bit_phase,
    output wire [7:0]  data_addr_reg,
    
    output wire        scl_drive_debug,
    output wire        sda_drive_debug,
    output wire        sda_in_debug,
    (* KEEP = "TRUE" *) output wire scl_calculated,
    (* KEEP = "TRUE" *) output wire sda_real,
    
    // Debug signals for ILA
    output wire [15:0] debug_w_data,
    output wire [15:0] debug_r_data,
    output wire [6:0]  debug_slave_addr,
    output wire        debug_multi_byte,
    output wire        debug_rw,
    output wire [7:0]  debug_reg_addr,
    output wire        debug_repeat_start
);

    reg [6:0]  slave_addr;
    reg [15:0] w_data;
    reg [7:0]  cmd_reg;
    reg        multi_byte;

    wire [15:0] master_r_data;
    wire        master_done;
    wire        master_error;
   
    reg         latched_rw;
    reg         latched_multi_byte;
    reg [7:0]   latched_cmd_reg;

    // Debug signal wires from master
    wire [15:0] master_debug_w_data;
    wire [15:0] master_debug_r_data;
    wire [6:0]  master_debug_slave_addr;
    wire        master_debug_multi_byte;
    wire        master_debug_rw;
    wire [7:0]  master_debug_reg_addr;
    wire        master_debug_repeat_start;

    i2c_master_general u_i2c (
        .start(start),
        .clk(clk),
        .reset_n(reset_n),
        .slave_addr(slave_addr),
        .rw(latched_rw),
        .reg_addr(latched_cmd_reg),
        .w_data(w_data),
        .multi_byte(latched_multi_byte),
        .r_data(master_r_data),
        .busy(busy),
        .ack_error(master_error),
        .done(master_done),
        .scl(scl),
        .sda(sda),
        .latch_start(),
        .state(master_state),
        .bit_cnt(bit_cnt),
        .bit_phase(bit_phase),
        .scl_drive_debug(scl_drive_debug),
        .sda_drive_debug(sda_drive_debug),
        .sda_in_debug(sda_in_debug),
        .scl_calculated(scl_calculated),
        .sda_real(sda_real),
        .scl_drive_direct(),
        .debug_w_data(master_debug_w_data),
        .debug_r_data(master_debug_r_data),
        .debug_slave_addr(master_debug_slave_addr),
        .debug_multi_byte(master_debug_multi_byte),
        .debug_rw(master_debug_rw),
        .debug_reg_addr(master_debug_reg_addr),
        .debug_repeat_start(master_debug_repeat_start)
    );

    always @(*) begin
        slave_addr = 7'h4B;
        cmd_reg    = 8'h00;
        multi_byte = 1'b0;

        case (high_level_cmd)
            3'b000: begin cmd_reg = 8'h00; multi_byte = 1'b1; end //temperature value
            3'b001: begin cmd_reg = 8'h02; end                    //status register
            3'b010: begin cmd_reg = 8'h0B; end                    //ID register
            3'b011: begin cmd_reg = 8'h03; end                    //configuration register
            3'b100: begin cmd_reg = 8'h04; multi_byte = 1'b1; end //Thigh setpoint register
            3'b101: begin cmd_reg = 8'h06; multi_byte = 1'b1; end //Tlow setpoint register
            3'b110: begin cmd_reg = 8'h08; multi_byte = 1'b1; end //Tcrit setpoint register
            3'b111: begin cmd_reg = 8'h0A; end                    //Thyst setpoint
            default: begin cmd_reg = 8'h00; multi_byte = 1'b0; end
        endcase
    end

    localparam [1:0] IDLE = 2'd0, COMPLETE = 2'd1;
    reg [1:0] state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state              <= IDLE;
            cmd_done           <= 1'b0;
            read_data          <= 16'h0000;
            error              <= 1'b0;
            start              <= 1'b0;
            start_latched      <= 1'b0;
            cmd_start_latched  <= 1'b0;
            latched_rw         <= 1'b0;
            latched_multi_byte <= 1'b0;
            latched_cmd_reg    <= 8'h00;
            w_data             <= 16'h0000;
        end else begin
            cmd_done <= 1'b0;
            error    <= master_error;

            if (cmd_start)
                cmd_start_latched <= 1'b1;

            case (state)
                IDLE: begin
                    start         <= 1'b0;
                    start_latched <= 1'b0;

                    if (cmd_start_latched && !busy) begin
                        latched_rw         <= rw;
                        latched_multi_byte <= multi_byte;
                        latched_cmd_reg    <= cmd_reg;
                        w_data             <= cmd_value;

                        start_latched      <= 1'b1;
                        cmd_start_latched  <= 1'b0;
                        state              <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    start <= start_latched;

                    if (start_latched && busy)
                        start_latched <= 1'b0;

                    if (master_done && !busy) begin
                        if (latched_rw && !master_error)
                            read_data <= master_r_data;

                        cmd_done <= 1'b1;
                        state    <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Debug signal assignments for ILA
    assign debug_w_data = master_debug_w_data;
    assign debug_r_data = master_debug_r_data;
    assign debug_slave_addr = master_debug_slave_addr;
    assign debug_multi_byte = master_debug_multi_byte;
    assign debug_rw = master_debug_rw;
    assign debug_reg_addr = master_debug_reg_addr;
    assign debug_repeat_start = master_debug_repeat_start;

endmodule

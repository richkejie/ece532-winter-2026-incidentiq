`timescale 1ns / 1ps

module i2c_master_general(
    input wire clk,
    input wire reset_n,
    input wire start,
    input wire [6:0] slave_addr,
    input wire rw,
    input wire [7:0] reg_addr,
    input wire [15:0] w_data,
    input wire multi_byte,
    output reg [15:0] r_data,
    output reg busy,
    output reg ack_error,
    output reg done,
    inout wire scl,
    inout wire sda,
    output reg latch_start,
    output reg [3:0] state,
    output reg [4:0] bit_phase,  // EXPANDED to 5 bits
    output reg [3:0] bit_cnt,
    
    output wire scl_drive_debug,
    output wire sda_drive_debug,
    output wire sda_in_debug,
    
    (* KEEP = "TRUE" *) output wire scl_calculated,
    (* KEEP = "TRUE" *) output wire sda_real,
    output wire scl_drive_direct,
    
    // Debug signals for ILA
    output wire [15:0] debug_w_data,
    output wire [15:0] debug_r_data,
    output wire [6:0] debug_slave_addr,
    output wire debug_multi_byte,
    output wire debug_rw,
    output wire [7:0] debug_reg_addr,
    output wire debug_repeat_start
);

parameter [15:0] PRESCALE = 250;  // Delay in system clock cycles

reg scl_drive;
reg sda_drive;

wire scl_in;
wire sda_in;

IOBUF #(
    .DRIVE(12),
    .IOSTANDARD("LVCMOS33")
) scl_iobuf_inst (
    .IO(scl),
    .O(scl_in),
    .I(1'b0),
    .T(~scl_drive)
);

IOBUF #(
    .DRIVE(12),
    .IOSTANDARD("LVCMOS33")
) sda_iobuf_inst (
    .IO(sda),
    .O(sda_in),
    .I(1'b0),
    .T(~sda_drive)
);

localparam IDLE = 4'd0, START_ST = 4'd1, START_WAIT = 4'd9, ADDR = 4'd2, ACK_ADDR = 4'd3, REG = 4'd4, ACK_REG = 4'd5, DATA = 4'd6, ACK_DATA = 4'd7, STOP_ST = 4'd8, RESTART_ST = 4'd10;

// PHY states for timing control
localparam [3:0] PHY_IDLE = 4'd0, PHY_BIT_SETUP = 4'd1, PHY_BIT_READ = 4'd2, PHY_WAIT = 4'd3;

// Bit phase states with wait cycles for PHY delay
localparam [4:0]
    PHASE_A_SETUP = 5'd0,      // Set SDA, pull SCL low
    PHASE_A_WAIT = 5'd1,       // Wait for PHY to apply
    PHASE_B_HIGH = 5'd2,       // Release SCL high
    PHASE_B_WAIT = 5'd3,       // Wait for PHY to apply
    PHASE_C_HOLD = 5'd4,       // Pull SCL low, prepare next bit
    PHASE_C_WAIT = 5'd5;       // Wait for PHY to apply

reg [3:0] phy_state;
reg [15:0] delay_cnt;
reg scl_drive_next, sda_drive_next;
reg phy_busy;

reg [7:0] data_addr_reg;
reg byte_index;
reg [15:0] w_buffer;
reg rw_flag;
reg [6:0] latch_slave_addr;
reg repeat_start;
reg [7:0] latch_reg_addr;

reg scl_in_r, sda_in_r;
reg scl_in_rr, sda_in_rr;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        scl_in_r <= 1'b1;
        scl_in_rr <= 1'b1;
        sda_in_r <= 1'b1;
        sda_in_rr <= 1'b1;
    end else begin
        scl_in_r <= scl_in;
        scl_in_rr <= scl_in_r;
        sda_in_r <= sda_in;
        sda_in_rr <= sda_in_r;
    end
end

// PHY layer - handles timing with delays (runs on system clock)
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        phy_state <= PHY_IDLE;
        delay_cnt <= 16'd0;
        scl_drive <= 1'b0;
        sda_drive <= 1'b0;
        phy_busy <= 1'b0;
    end else begin
        case (phy_state)
            PHY_IDLE: begin
                phy_busy <= 1'b0;
                scl_drive <= scl_drive_next;
                sda_drive <= sda_drive_next;
                // Always start delay - uniform timing for every cycle
                delay_cnt <= PRESCALE;
                phy_state <= PHY_WAIT;
                phy_busy <= 1'b1;
            end
            
            PHY_WAIT: begin
                if (delay_cnt > 0) begin
                    delay_cnt <= delay_cnt - 1;
                    phy_busy <= 1'b1;
                end else begin
                    phy_state <= PHY_IDLE;
                    phy_busy <= 1'b0;
                end
            end
        endcase
    end
end

// Main FSM - protocol logic (runs on system clock)
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= IDLE;
        busy <= 0;
        ack_error <= 0;
        scl_drive_next <= 0;
        sda_drive_next <= 0;
        r_data <= 16'h0;
        done <= 0;
        repeat_start <= 0;
        latch_start <= 0;
        bit_cnt <= 4'd7;
        bit_phase <= PHASE_A_SETUP;
        byte_index <= 1'b0;
        w_buffer <= 16'h0000;
        rw_flag <= 1'b0;
        latch_slave_addr <= 7'h00;
        latch_reg_addr <= 8'h00;
    end else if (!phy_busy) begin
        case (state)
            IDLE: begin
                done <= 0;
                scl_drive_next <= 0;
                sda_drive_next <= 0;
                latch_start <= 0;
                ack_error <= 0;

                if (start && !busy) begin
                    latch_start <= 1;
                    busy <= 1;
                    state <= START_ST;

                    byte_index <= multi_byte;
                    w_buffer <= w_data;
                    latch_slave_addr <= slave_addr;
                    latch_reg_addr <= reg_addr;
                    r_data <= 16'h0000;

                    repeat_start <= rw;
                    rw_flag <= 0;
                    bit_cnt <= 7;
                    bit_phase <= PHASE_A_SETUP;
                end
            end
            
            START_ST: begin
                latch_start <= 0;
                sda_drive_next <= 1;  // Pull SDA low
                scl_drive_next <= 0;  // Release SCL (keep high)
                state <= START_WAIT;
            end

            START_WAIT: begin
                sda_drive_next <= 1;
                scl_drive_next <= 1;  // NOW pull SCL low (after setup delay)
                data_addr_reg <= { latch_slave_addr, rw_flag };
                state <= ADDR;
                bit_cnt <= 7;
                bit_phase <= PHASE_A_SETUP;
            end

            ADDR: begin
                case (bit_phase)
                    PHASE_A_SETUP: begin  // Setup - SCL low, set SDA
                        scl_drive_next <= 1;
                        sda_drive_next <= ~data_addr_reg[bit_cnt];
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin  // Wait for PHY to apply changes
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin  // Release SCL high
                        scl_drive_next <= 0;
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin  // Wait for PHY to apply
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin  // Pull SCL low, prepare next bit
                        scl_drive_next <= 1;
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin  // Wait for PHY, then back to phase A
                        if (bit_cnt == 4'd0) begin
                            state <= ACK_ADDR;
                            bit_phase <= PHASE_A_SETUP;
                        end else begin
                            bit_phase <= PHASE_A_SETUP;
                            bit_cnt <= bit_cnt - 1;
                            sda_drive_next <= ~data_addr_reg[bit_cnt - 1];  // Prepare next bit
                        end
                    end
                endcase
            end

            ACK_ADDR: begin
                case (bit_phase)
                    PHASE_A_SETUP: begin  // Setup - SCL low, release SDA for slave
                        scl_drive_next <= 1;
                        sda_drive_next <= 0;  // Release SDA (slave pulls low for ACK)
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin  // SCL high, read ACK bit
                        scl_drive_next <= 0;  // Release SCL high
                        ack_error <= sda_in_rr;  // Read SDA while SCL is high
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin  // Pull SCL low, hold SDA
                        scl_drive_next <= 1;
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin
                        if (ack_error) begin  // NACK received
                            state <= STOP_ST;
                            bit_phase <= PHASE_A_SETUP;
                        end else begin  // ACK received
                            sda_drive_next <= 1;
                            bit_cnt <= 7;
                            bit_phase <= PHASE_A_SETUP;
                            // if (rw_flag == 1'b1) begin //check this - think this is good
                            if (rw_flag == 1'b0) begin //check this - think this is good
                                state <= REG;
                                data_addr_reg <= latch_reg_addr;
                            end else begin //for reads, go to data directly
                                state <= DATA;
                                sda_drive_next <= 0;
                            end
                        end
                    end
                endcase
            end
            
            REG: begin
                case (bit_phase)
                    PHASE_A_SETUP: begin  // Setup - SCL low, set SDA
                        scl_drive_next <= 1;
                        sda_drive_next <= ~data_addr_reg[bit_cnt];
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin  // Wait for PHY to apply changes
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin  // Release SCL high
                        scl_drive_next <= 0;
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin  // Wait for PHY to apply
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin  // Pull SCL low, prepare next bit
                        scl_drive_next <= 1;
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin  // Wait for PHY, then back to phase A
                        if (bit_cnt == 4'd0) begin
                            state <= ACK_REG;
                            bit_phase <= PHASE_A_SETUP;
                        end else begin
                            bit_phase <= PHASE_A_SETUP;
                            bit_cnt <= bit_cnt - 1;
                            sda_drive_next <= ~data_addr_reg[bit_cnt - 1];  // Prepare next bit
                        end
                    end
                endcase
            end

            ACK_REG: begin
                case (bit_phase)
                    PHASE_A_SETUP: begin  // Setup - SCL low, release SDA for slave
                        scl_drive_next <= 1;
                        sda_drive_next <= 0;  // Release SDA (slave pulls low for ACK)
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin  // SCL high, read ACK bit
                        scl_drive_next <= 0;  // Release SCL high
                        ack_error <= sda_in_rr;  // Read SDA while SCL is high
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin  // Pull SCL low, hold SDA
                        scl_drive_next <= 1;
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin
                        if (ack_error) begin  // NACK received
                            state <= STOP_ST;
                            bit_phase <= PHASE_A_SETUP;
                        end else begin  // ACK received
                            sda_drive_next <= 1;
                            bit_cnt <= 7;
                            bit_phase <= PHASE_A_SETUP;
                            if (repeat_start) begin  // If rw_flag=1, we're in read mode (after repeated START)
//                                state <= DATA;   // Skip REG, go straight to DATA
                                state <= RESTART_ST;
                                sda_drive_next <= 1;
                                rw_flag <= 1;
                            end else begin  // If rw_flag=0, send register address
                                state <= DATA;
                                data_addr_reg <= latch_reg_addr;
                            end
                        end
                    end
                endcase
            end

            RESTART_ST: begin
                // Repeated START using 6-phase timing with symmetric SCL pulses
                case (bit_phase)
                    PHASE_A_SETUP: begin  // Pull SCL LOW first
                        scl_drive_next <= 1;  // Pull SCL LOW
                        sda_drive_next <= 0;  // Release SDA (goes HIGH)
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin  // Wait for SCL to settle LOW
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin  // Release SCL HIGH
                        scl_drive_next <= 0;  // Release SCL (goes HIGH via pull-up)
                        sda_drive_next <= 0;  // Keep SDA released (HIGH)
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin  // SCL is HIGH, NOW pull SDA LOW (creates repeated START)
                        scl_drive_next <= 0;  // Keep SCL released (stays HIGH)
                        sda_drive_next <= 1;  // Pull SDA LOW while SCL is HIGH ? REPEATED START HERE
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin  // Pull SCL LOW
                        scl_drive_next <= 1;  // Pull SCL LOW (end of START condition)
                        sda_drive_next <= 1;  // Keep SDA LOW
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin  // Wait for SCL to settle LOW, then transition to ADDR
                        data_addr_reg <= { latch_slave_addr, repeat_start };
                        repeat_start <= 0;
                        state <= ADDR;
                        bit_cnt <= 7;
                        bit_phase <= PHASE_A_SETUP;
                    end
                endcase
            end

            DATA: begin //TODO: i think logic is fine, its just that repeat_start gets reset earlier so it all goes to write. use different flag to detect above so that i dont get this issue.
                if (rw_flag == 1'b0) begin
                    // Write operation
                    case (bit_phase)
                        PHASE_A_SETUP: begin  // Setup - SCL low, set SDA
                            scl_drive_next <= 1;
                            sda_drive_next <= ~w_buffer[byte_index*8 + bit_cnt];
                            bit_phase <= PHASE_A_WAIT;
                        end
                        
                        PHASE_A_WAIT: begin  // Wait for PHY to apply changes
                            bit_phase <= PHASE_B_HIGH;
                        end
                        
                        PHASE_B_HIGH: begin  // Release SCL high
                            scl_drive_next <= 0;
                            bit_phase <= PHASE_B_WAIT;
                        end
                        
                        PHASE_B_WAIT: begin  // Wait for PHY to apply
                            bit_phase <= PHASE_C_HOLD;
                        end
                        
                        PHASE_C_HOLD: begin  // Pull SCL low, prepare next bit
                            scl_drive_next <= 1;
                            bit_phase <= PHASE_C_WAIT;
                        end
                        
                        PHASE_C_WAIT: begin  // Wait for PHY, then back to phase A
                            if (bit_cnt == 4'd0) begin
                                state <= ACK_DATA;
                                bit_phase <= PHASE_A_SETUP;
                            end else begin
                                bit_phase <= PHASE_A_SETUP;
                                bit_cnt <= bit_cnt - 1;
                                sda_drive_next <= ~w_buffer[byte_index*8 + bit_cnt - 1];  // Prepare next bit
                            end
                        end
                    endcase
                end else begin
                    // Read operation
                    case (bit_phase)
                        PHASE_A_SETUP: begin  // Setup - SCL low, release SDA for slave
                            scl_drive_next <= 1;
                            sda_drive_next <= 0;
                            bit_phase <= PHASE_A_WAIT;
                        end
                        
                        PHASE_A_WAIT: begin  // Wait for PHY to apply changes
                            bit_phase <= PHASE_B_HIGH;
                        end
                        
                        PHASE_B_HIGH: begin  // Release SCL high, slave drives SDA
                            scl_drive_next <= 0;
                            bit_phase <= PHASE_B_WAIT;
                        end
                        
                        PHASE_B_WAIT: begin  // Wait for PHY, THEN read bit (slave has time to drive SDA)
                            r_data[byte_index*8 + bit_cnt] <= sda_in_rr;  // READ here after SCL is stable HIGH
                            bit_phase <= PHASE_C_HOLD;
                        end
                        
                        PHASE_C_HOLD: begin  // Pull SCL low
                            scl_drive_next <= 1;
                            bit_phase <= PHASE_C_WAIT;
                        end
                        
                        PHASE_C_WAIT: begin  // Wait for PHY, then back to phase A
                            if (bit_cnt == 4'd0) begin
                                state <= ACK_DATA;
                                bit_phase <= PHASE_A_SETUP;
                                sda_drive_next <= (byte_index == 1) ? 1 : 0;
                            end else begin
                                bit_phase <= PHASE_A_SETUP;
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    endcase
                end
            end

            ACK_DATA: begin
                case (bit_phase)
                    PHASE_A_SETUP: begin
                        scl_drive_next <= 0;
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin
                        ack_error <= sda_in_rr;  // Read ACK for write, or just read for final read
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin
                        scl_drive_next <= 1;
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin
                        if (rw_flag == 1'b1) begin
                            ack_error <= 1'b0;
                            
                            if (byte_index) begin
                                byte_index <= 0;
                                bit_cnt <= 7;
                                bit_phase <= PHASE_A_SETUP;
                                state <= DATA;
                                scl_drive_next <= 1;
                                sda_drive_next <= 0;
                            end else begin
                                state <= STOP_ST;
                                bit_phase <= PHASE_A_SETUP;
                            end
                        end else begin
                            if (ack_error) begin  // NACK
                                state <= STOP_ST;
                                bit_phase <= PHASE_A_SETUP;
                            end else begin  // ACK
                                if (byte_index) begin
                                    byte_index <= 0;
                                    bit_cnt <= 7;
                                    bit_phase <= PHASE_A_SETUP;
                                    state <= DATA;
                                    scl_drive_next <= 1;
                                    sda_drive_next <= 1;
                                end else begin
                                    state <= STOP_ST;
                                    bit_phase <= PHASE_A_SETUP;
                                end
                            end
                        end
                    end
                endcase
            end

            STOP_ST: begin
                // Proper STOP condition using 6-phase timing
                case (bit_phase)
                    PHASE_A_SETUP: begin  // Pull SCL LOW first
                        scl_drive_next <= 1;  // Pull SCL LOW
                        sda_drive_next <= 1;  // Keep SDA LOW
                        bit_phase <= PHASE_A_WAIT;
                    end
                    
                    PHASE_A_WAIT: begin  // Wait for SCL to settle LOW
                        bit_phase <= PHASE_B_HIGH;
                    end
                    
                    PHASE_B_HIGH: begin  // Release SCL HIGH
                        scl_drive_next <= 0;  // Release SCL (goes HIGH via pull-up)
                        sda_drive_next <= 1;  // Keep SDA LOW
                        bit_phase <= PHASE_B_WAIT;
                    end
                    
                    PHASE_B_WAIT: begin  // SCL is HIGH, NOW release SDA (creates STOP condition)
                        scl_drive_next <= 0;  // Keep SCL released (stays HIGH)
                        sda_drive_next <= 0;  // Release SDA to go HIGH while SCL is HIGH ? STOP HERE
                        bit_phase <= PHASE_C_HOLD;
                    end
                    
                    PHASE_C_HOLD: begin  // Both lines released (HIGH)
                        scl_drive_next <= 0;
                        sda_drive_next <= 0;
                        bit_phase <= PHASE_C_WAIT;
                    end
                    
                    PHASE_C_WAIT: begin  // Wait for lines to settle, then done
                        busy <= 0;
                        done <= 1;
                        state <= IDLE;
                        bit_phase <= PHASE_A_SETUP;
                    end
                endcase
            end

            default: state <= IDLE;
        endcase
    end
end

(* KEEP = "TRUE" *) wire scl_drive_debug_keep;
(* KEEP = "TRUE" *) wire sda_drive_debug_keep;
(* KEEP = "TRUE" *) wire sda_in_debug_keep;
(* KEEP = "TRUE" *) wire scl_calculated_keep;
(* KEEP = "TRUE" *) wire sda_real_keep;

assign scl_drive_debug = scl_drive_debug_keep;
assign sda_drive_debug = sda_drive_debug_keep;
assign sda_in_debug = sda_in_debug_keep;
assign scl_calculated = scl_calculated_keep;
assign sda_real = sda_real_keep;

assign scl_drive_debug_keep = scl_drive;
assign sda_drive_debug_keep = sda_drive;
assign sda_in_debug_keep = sda_in;
assign scl_calculated_keep = ~scl_drive;
assign sda_real_keep = sda_in;
assign scl_drive_direct = scl_drive;

// Debug signal assignments for ILA
assign debug_w_data = w_data;
assign debug_r_data = r_data;
assign debug_slave_addr = slave_addr;
assign debug_multi_byte = multi_byte;
assign debug_rw = rw;
assign debug_reg_addr = reg_addr;
assign debug_repeat_start = repeat_start;

endmodule

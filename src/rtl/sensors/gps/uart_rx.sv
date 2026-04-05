`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Darrian Shue
// 
// Create Date: 02/05/2026 09:49:47 PM
// Design Name: 
// Module Name: uart_rx
// Project Name: IncidentIQ
// Target Devices: 
// Tool Versions: 
// Description: UART RX module
// 
// Dependencies: 
// 
// Revision: 1.0
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_rx #(
    parameter int CLK_SPEED = 100_000_000, // sys clock
    parameter int BAUD_RATE = 9600 // this is changeable if we build uart_tx
    )(
    input logic clk,
    input logic rst, // not sure this is needed since need to connect J2 pin on PMOD for this to do anything
    input logic rx, // UART RX pin
    
    output logic[7:0] rx_byte, // full output byte
    output logic rx_valid, // valid UART RX byte
    output logic byte_error // error in decoding a UART byte transmission
    );
    
    // calculate number of clock cycles per UART bit
    localparam int BAUD_DIV = (CLK_SPEED + BAUD_RATE/2) / BAUD_RATE; // round to nearest integer number of clock cycles for one bit transmission
    localparam int CNT_BIT = $clog2(BAUD_DIV);
    
    logic[CNT_BIT:0] baud_cnt;
    logic[2:0] bit_idx; // used to keep track of which bit in UART byte transmission we are on
    logic[7:0] shift_reg; // store UART byte
    
    // UART byte transmission FSM
    typedef enum logic [1:0] {
        S_IDLE = 2'b00,
        S_START = 2'b01,
        S_DATA = 2'b10,
        S_STOP = 2'b11
    } state_t;
    
    state_t state; 
    
    always_ff @(posedge clk) begin
        if (rst) begin // again, we don't necessarily have a reset if we use the GPS PMOD
            state <= S_IDLE;
            baud_cnt <= '0;
            bit_idx <= 3'b0;
            shift_reg <= 8'b0;
            rx_byte <= 8'b0;
            rx_valid <= 1'b0;
            byte_error <= 0;
        end else begin
            rx_valid <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    byte_error <= 1'b0;
                    bit_idx <= 3'b0;
                    if (rx == 1'b0) begin // possible valid start bit
                        baud_cnt <= BAUD_DIV / 2; // set counter to sample the middle of this bit
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (baud_cnt != 0) begin // keep waiting until half a bit worth of clock cycles has passed
                        baud_cnt <= baud_cnt - 1;
                    end else begin
                        if (rx == 1'b0) begin // valid start bit
                            baud_cnt <= BAUD_DIV - 1; // set counter to sample in the middle of the next bit
                            state <= S_DATA;
                        end else begin // invalid start bit, return to IDLE
                            state <= S_IDLE;
                        end
                    end
                end
                S_DATA: begin
                    if (baud_cnt != 0) begin // keep waiting until middle of next bit transmission
                        baud_cnt <= baud_cnt - 1;
                    end else begin
                        shift_reg[bit_idx] <= rx;
                        if (bit_idx == 3'b111) begin // read last bit, move to next state
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                        baud_cnt <= BAUD_DIV - 1; // set counter to sample in the middle of the next bit
                    end
                end
                S_STOP: begin
                    if (baud_cnt != 0) begin // keep waiting until middle of possible stop bit
                        baud_cnt <= baud_cnt - 1;
                    end else begin
                        if (rx == 1'b1) begin // byte transmission complete
                            rx_byte <= shift_reg;
                            rx_valid <= 1'b1;
                            byte_error <= 1'b0;
                        end else begin // byte transmission failed, no stop bit
                            byte_error <= 1'b1;
                        end
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

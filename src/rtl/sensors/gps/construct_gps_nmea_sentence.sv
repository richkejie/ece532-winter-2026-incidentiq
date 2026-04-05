`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/06/2026 01:44:22 PM
// Design Name: 
// Module Name: construct_gps_nmea_sentence
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// The GPS module sends complete UART NMEA sentences, delineated by the '$' starting character and <CR><LF> ending characters
//////////////////////////////////////////////////////////////////////////////////


module construct_gps_nmea_sentence #(
    parameter int MAX_BYTES = 128 // maximum number of bytes per NMEA sentence
    )(
    input logic clk,
    input logic rst,
    input logic[7:0] rx_byte, // byte output from UART RX
    input logic rx_valid, // byte is valid
    // input logic byte_error, // error in decoding a UART byte transmission
    
    output logic[MAX_BYTES*8-1:0] out_sentence, // store latest RMC message
    output logic[$clog2(MAX_BYTES+1)-1:0] out_len, // length of latest RMC message (remaining bytes may be garbage)

    output logic in_sentence
);

    localparam int MAX_BYTES_SIZE = $clog2(MAX_BYTES+1); // number of bits required to store address of bytes, ex 0,1,2,3 requires 2 bits
    
    // ping pong buffer, each buffer is an array of bytes
    logic[7:0] buf0 [0:MAX_BYTES-1];
    logic[7:0] buf1 [0:MAX_BYTES-1]; 
    logic buf_sel; // select which ping pong buffer to use
    
    logic [MAX_BYTES_SIZE-1:0] wr_idx;

    logic[2:0] header_pos; // header to track position of RMC Message ID (which can only be at positions 3...5)
    logic is_rmc;
    logic overflow;
    logic prev_was_cr = 1'b0; // boolean to see if the previous byte was the ASCII <CR> control code
    
    integer i = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            buf_sel <= 1'b0;
            wr_idx <= '0;
            in_sentence <= 1'b0;
            header_pos <= '0;
            is_rmc <= 1'b0;
            out_sentence <= '0;
            out_len <= '0;
            overflow <= 1'b0;
            prev_was_cr <= 1'b0;
            
            for (int i = 0; i < MAX_BYTES; i++) begin
                buf0[i] = 8'd0;
                buf1[i] = 8'd0;
            end
            
        end else begin
            if (rx_valid) begin // valid UART byte received 
                if (!in_sentence) begin // not in the middle of a sentence, so look for start character '$'
                    if (rx_byte == 8'h24) begin // 0x24 = '$'
                        in_sentence <= 1'b1;
                        header_pos <= 3'd0;
                        is_rmc <= 1'b0;
                        overflow <= 1'b0;

                        // store first byte into active buffer, '$' as first character
                        if (buf_sel == 1'b0) begin
                            buf0['0] <= 8'h24;
                        end else begin 
                            buf1['0] <= 8'h24;
                        end
                        wr_idx <= 1;
                        prev_was_cr <= 1'b0;
                    end
                end else begin // in the middle of a sentence
                    if (header_pos < 3'd6) begin // update the header if we are still within MessageID field (first 6 characters)
                        header_pos <= header_pos + 1'b1;
                    end
                    
                    prev_was_cr <= (rx_byte == 8'h0D);
                    
                    // determines if message type is RMC, ex '$GPRMC,...'
                    unique case (header_pos + 3'd1)
                        3'd3: is_rmc <= (rx_byte == "R");
                        3'd4: is_rmc <= is_rmc && (rx_byte == "M");
                        3'd5: is_rmc <= is_rmc && (rx_byte == "C");
                        default: ; // do nothing
                    endcase
                    
                    if (!overflow) begin
                        if (wr_idx < MAX_BYTES) begin // <LF> byte overflow check
                            // store byte into active buffer
                            if (buf_sel == 1'b0) begin
                                buf0[wr_idx] <= rx_byte;
                            end else begin
                                buf1[wr_idx] <= rx_byte;
                            end
                            wr_idx <= wr_idx + 1'b1;
                        end else begin
                            overflow <= 1'b1;
                        end
                    end
                    
                    if (rx_byte == 8'h0A && prev_was_cr) begin // ending ASCII control <LF> character detected preceded by <CR>
                        in_sentence <= 1'b0;

                        if (is_rmc && !overflow) begin // copy active buffer into output, note apparently its not good to have for loops in always_ff
                            for (i = 0; i < MAX_BYTES; i++) begin // clear each byte in output
                                out_sentence[i*8 +: 8] <= 8'h00;
                            end
                            for (i = 0; i < MAX_BYTES; i++) begin // copy valid bytes into output
                                if (i < wr_idx) begin
                                    if (i == (wr_idx - 1)) begin
                                        out_sentence[i*8 +: 8] <= rx_byte;
                                    end else begin
                                        if (buf_sel == 1'b0) begin
                                            out_sentence[i*8 +: 8] <= buf0[i];
                                        end else begin
                                            out_sentence[i*8 +: 8] <= buf1[i];
                                        end
                                    end
                                end
                            end
                            out_len <= wr_idx;
                        end
                        
                        buf_sel <= ~buf_sel; // switch other buffer to active

                        // reset values for next sentence
                        wr_idx <= '0;
                        header_pos <= '0;
                        is_rmc <= 1'b0;
                        overflow <= 1'b0;
                        prev_was_cr <= 1'b0;
                        
                        if (buf_sel == 1'b0) begin
                            for (int i = 0; i < MAX_BYTES; i++) begin
                                buf0[i] = 8'd0;
                            end
                        end else begin
                            for (int i = 0; i < MAX_BYTES; i++) begin
                                buf1[i] = 8'd0;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule

`timescale 1ns / 1ps

module bram_writer(
    input   logic           clk,
    input   logic           arst_n,
    input   logic           i_valid,
    input   logic [31:0]    i_data,
    input   logic [31:0]    i_bram_addr,
    
    output  logic [31:0]    o_bram_addr,
    output  logic [31:0]    o_bram_din,
    output  logic [3:0]     o_bram_we,
    output  logic           o_bram_en
    );
    
    assign o_bram_en = 1'b1; // always enabled
    
    always @(posedge clk or negedge arst_n) begin
        if (~arst_n) begin
            o_bram_addr       <= '0;
            o_bram_din        <= '0;
            o_bram_we         <= '0;
        end else begin
            if (i_valid) begin
                o_bram_addr   <= i_bram_addr;
                o_bram_din    <= i_data;
                o_bram_we     <= 4'b1111; // write all 4 bytes
            end else begin
                o_bram_addr   <= '0;
                o_bram_din    <= '0;
                o_bram_we     <= '0;
            end
        end
    end
endmodule

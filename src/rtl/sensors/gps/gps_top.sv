`timescale 1ns / 1ps

module gps_top (
    input  logic        clk,      // 100 MHz
    input  logic        btnC,     // center button = reset
    input  logic        gps_rx,   // PMOD JA pin 3
    output logic [15:0] led       // Nexys 4 DDR has 16 LEDs
);

    localparam int CLK_SPEED = 100_000_000;
    localparam int BAUD_RATE = 9600;
    localparam int MAX_BYTES = 128;

    logic [7:0] rx_byte;
    logic       rx_valid;
    logic       byte_error;
    logic       in_sentence;
    logic [1023:0] out_sentence;
    logic [7:0] out_len;

    uart_rx #(
        .CLK_SPEED(CLK_SPEED),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk       (clk),
        .rst       (btnC),
        .rx        (gps_rx),
        .rx_byte   (rx_byte),
        .rx_valid  (rx_valid),
        .byte_error(byte_error)
    );

    construct_gps_nmea_sentence #(
        .MAX_BYTES(MAX_BYTES)
    ) u_nmea (
        .clk         (clk),
        .rst         (btnC),
        .rx_byte     (rx_byte),
        .rx_valid    (rx_valid),
        .out_sentence(out_sentence), // not used yet
        .out_len     (out_len), // not used yet
        .in_sentence (in_sentence)
    );

    // LED assignments
    assign led[7:0]  = rx_byte;     // current byte value on lower 8 LEDs
    assign led[8]    = rx_valid;     // pulses when a byte is received
    assign led[9]    = in_sentence;  // high while a sentence is being received
    assign led[10]   = byte_error;   // lights up if UART decode error
    assign led[15:11] = 5'b0;        // unused

    ila_0 u_ila (
        .clk    (clk),
        .probe0 (rx_valid),           // 1 bit
        .probe1 (rx_byte),            // 8 bits
        .probe2 (in_sentence),        // 1 bit
        .probe3 (out_len),           // 8 bits
        .probe4 (out_sentence[79:0]) // 80 bits
    );

endmodule

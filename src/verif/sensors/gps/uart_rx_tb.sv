`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Darrian Shue
// 
// Create Date: 02/06/2026 07:48:26 PM
// Design Name: 
// Module Name: uart_rx_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench for UART RX module
// 
// Dependencies: 
// 
// Revision: 1.0
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_rx_tb;
    localparam int CLK_SPEED = 100_000_000;
    localparam int BAUD_RATE = 9600;
    
    localparam time CLK_PER_NS = 1_000_000_000 / CLK_SPEED; // 10ns at 100MHz
    localparam time BIT_PER_NS = 1_000_000_000 / BAUD_RATE; // ~104166ns at 9600
    
    logic clk = 0;
    logic rst = 1;
    logic rx;
    
    logic[7:0] rx_byte;
    logic rx_valid;
    logic byte_error;
    
    // clock
    always #(CLK_PER_NS/2) clk = ~clk;
    
    uart_rx #(
        .CLK_SPEED(CLK_SPEED),
        .BAUD_RATE(BAUD_RATE)
        ) dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid),
        .byte_error(byte_error)
        );
    
    task automatic uart_send_byte(input byte b); // task to send one single byte of data over rx
        int i;
        int BAUD_DIV_TB;
        begin
            BAUD_DIV_TB = (CLK_SPEED + BAUD_RATE/2) / BAUD_RATE;
            
            rx <= 1'b1; // idle high
            repeat (BAUD_DIV_TB) @(posedge clk);
            
            rx <= 1'b0; // start bit low
            repeat (BAUD_DIV_TB) @(posedge clk);
            
            for (i = 0; i < 8; i++) begin // 8 data bits
                rx <= b[i];
                repeat (BAUD_DIV_TB) @(posedge clk);
            end
            
            rx <= 1'b1; // stop bit high + idle
            repeat (BAUD_DIV_TB) @(posedge clk);
            repeat (BAUD_DIV_TB) @(posedge clk);
        end
    endtask
    
    task automatic expect_byte(input byte exp); // check rx_valid and compare to expected byte
        begin
            @(posedge clk);
            wait (rx_valid === 1'b1);
            if (rx_byte !== exp) begin
                $fatal(1, "UART RX mismatch: got 0x%02h expected 0x%02h", rx_byte, exp);
            end
            if (byte_error) begin
                $fatal(1, "Unexpected byte_error asserted on good byte 0x%02h", exp);
            end
            @(posedge clk);
            end
    endtask
    
    task automatic uart_send_bad_stop(input byte b);
        int i;
        begin
            rx <= 1'b0; #(BIT_PER_NS); // start bit low
            for (i=0;i<8;i++) begin rx <= b[i]; #(BIT_PER_NS); end // data bits
            rx <= 1'b0; #(BIT_PER_NS); // end bit low, should assert byte_error
            rx <= 1'b1; #(BIT_PER_NS); // return to idle
        end
    endtask
    
    task automatic uart_check_send_bad_stop();
        begin
            @(posedge clk);
            wait (byte_error === 1'b1);
            $display("Expected byte_error observed for bad stop bit.");
            @(posedge clk);
        end
    endtask
    
    // tests
    initial begin
        rx = 1'b1;
        
        // reset
        repeat (5) @(posedge clk);
        rst <= 0;
        repeat (5) @(posedge clk);
        
        // send a few bytes, check simultaneously
        fork
            begin
                uart_send_byte(8'h55);
                uart_send_byte(8'hA3);
                uart_send_byte("Z");
            end
            begin
                expect_byte(8'h55);
                expect_byte(8'hA3);
                expect_byte("Z");
            end
        join
        
        // test byte error (framing error)
        fork
            begin
                uart_send_bad_stop(8'hCC);
            end
            begin
                uart_check_send_bad_stop();
            end
        join
        
        $display("tb_uart_rx: PASS");
        $finish;
    end

endmodule

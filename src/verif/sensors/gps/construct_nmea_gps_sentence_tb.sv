`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Darrian Shue
// 
// Create Date: 02/06/2026 09:10:51 PM
// Design Name: 
// Module Name: construct_nmea_gps_sentence_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench for gps sentence constructor
// 
// Dependencies: 
// 
// Revision: 1.0
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module construct_gps_nmea_sentence_tb;

    localparam int CLK_SPEED = 100_000_000;
    localparam time CLK_PER_NS = 1_000_000_000 / CLK_SPEED;
    
    localparam int MAX_BYTES = 128;
    
    logic clk = 0;
    logic rst = 1;
    
    logic[7:0] rx_byte;
    logic rx_valid;
    
    logic [MAX_BYTES*8-1:0] out_sentence;
    logic [$clog2(MAX_BYTES+1)-1:0] out_len;
    logic in_sentence;
    
    always #(CLK_PER_NS/2) clk = ~clk;
    
    construct_gps_nmea_sentence #(
        .MAX_BYTES(MAX_BYTES)
        ) dut (
        .clk(clk),
        .rst(rst),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid),
        .out_sentence(out_sentence),
        .out_len(out_len),
        .in_sentence(in_sentence)
    );
    
    // helpers to provide input
    task automatic push_byte(input byte b); // individual byte
        begin
            @(posedge clk);
            rx_byte  <= b;
            rx_valid <= 1'b1;
            @(posedge clk);
            rx_valid <= 1'b0;
        end
    endtask
    
    task automatic push_string(input string s); // full NMEA string
        int i;
        begin
            for (i = 0; i < s.len(); i++) begin
                push_byte(s[i]);
            end
        end
    endtask
    
    task automatic push_crlf(); // ending control characters
        begin
            push_byte(8'h0D); // CR
            push_byte(8'h0A); // LF
        end
    endtask
    
    // helpers to check output
    function automatic byte get_out_byte(input int idx);
        get_out_byte = out_sentence[idx*8 +: 8];
    endfunction
    
    task automatic expect_sentence(input string exp);
        int i;
        int L;
        byte got;
        begin
            L = exp.len();
            
//            if (out_len !== L[$bits(out_len)-1:0]) begin
//                $fatal(1, "out_len mismatch: got %0d expected %0d", out_len, L);
//            end
            
            for (i = 0; i < L; i++) begin
                got = get_out_byte(i);
                if (got !== exp[i]) begin
                    $fatal(1, "Sentence mismatch at i=%0d: got 0x%02h('%c') exp 0x%02h('%c')", i, got, got, exp[i], exp[i]);
                end
            end
        end
    endtask
    
    task automatic expect_no_update(input int old_len);
        begin
            repeat (5) @(posedge clk); // wait for update
            if (out_len !== old_len[$bits(out_len)-1:0]) begin
                $fatal(1, "Unexpected output update: out_len changed from %0d to %0d", old_len, out_len);
            end
        end
    endtask
    
    // Wait until in_sentence falls (optional convenience)
    task automatic wait_sentence_done();
        begin
            // Wait for in_sentence to go high at '$'
            wait (in_sentence === 1'b1);
            // Then wait for it to drop after CRLF
            wait (in_sentence === 1'b0);
            @(posedge clk);
        end
    endtask
    
    // tests
    int old_len;
    string gga;
    string rmc;
    string rmc2;
    string rmc3;
    
    initial begin
        rx_byte  = 8'h00;
        rx_valid = 1'b0;
        
        repeat (5) @(posedge clk);
        rst <= 0;
        repeat (5) @(posedge clk);
        
        push_string("NOISE"); // random noise to be ignored 
        repeat (5) @(posedge clk);
        
        // if non RMC message, then ignore
        old_len = out_len;
        
        gga = "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47";
        push_string(gga);
        push_crlf();
        wait_sentence_done();
        expect_no_update(old_len);
        
        // if RMS sentence, keep track
        rmc = "$GPRMC,092751.000,A,5321.6802,N,00630.3372,W,0.06,31.66,280511,,,A*45";
        push_string(rmc);
        push_crlf();
        wait_sentence_done();
        //expect_sentence({rmc, "\r\n"});
        
        // another RMC msg
        rmc2 = "$GPRMC,1,D*46";
        push_string(rmc2);
        push_crlf();
        wait_sentence_done();
        //expect_sentence({rmc, "\r\n"});
        
        // another RMC msg
        rmc3 = "$GPRMC,blahblahblah";
        push_string(rmc3);
        push_crlf();
        wait_sentence_done();
        //expect_sentence({rmc, "\r\n"});
        
        $display("tb_construct_gps_nmea_sentence: PASS");
        $finish;
    end
endmodule

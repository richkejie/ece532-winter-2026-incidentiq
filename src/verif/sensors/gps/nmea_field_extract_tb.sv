`timescale 1ns / 1ps

module tb_nmea_field_extract;
    parameter SENTENCE_BITS = 1024;

    logic clk;
    logic [SENTENCE_BITS-1:0] sentence;

    logic [31:0] utc_time;
    logic [31:0] latitude;
    logic north;
    logic [31:0] longitude;
    logic east;
    logic [31:0] ground_speed;

    nmea_field_extract #(
        .SENTENCE_BITS(SENTENCE_BITS)
    ) test (
        .clk(clk),
        .sentence(sentence),
        .utc_time(utc_time),
        .latitude(latitude),
        .north(north),
        .longitude(longitude),
        .east(east),
        .ground_speed(ground_speed)
    );

    // clock gen
    initial clk = 0;
    always #5 clk = ~clk;

    // convert string to 1024 bit signal
    function logic [SENTENCE_BITS-1:0] string_to_bits(input string s);
        logic [SENTENCE_BITS-1:0] tmp = '0;
        for (int i = 0; i < s.len() && i < 128; i++) begin
            tmp[8*(127-i) +: 8] = s[i];
        end
        return tmp;
    endfunction

    initial begin
    
        // for some reason the uart gps extractor module outputs a reversed ASCII sentence
        string test_sentence = "55*A,W,50.3,604062,84.561,23.1,E,0344.61021,N,0521.7032,A,301.159460,CMRPG$";

        sentence = string_to_bits(test_sentence);

        #20;

        // display outputs
        $display("UTC Time     : %0d", utc_time);
        $display("Latitude     : %0d", latitude);
        $display("North/South  : %s", north ? "N" : "S");
        $display("Longitude    : %0d", longitude);
        $display("East/West    : %s", east ? "E" : "W");
        $display("Ground Speed : %0d", ground_speed);

        $finish;
    end

endmodule

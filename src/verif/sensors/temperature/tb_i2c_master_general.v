`timescale 1ns/1ps

module tb_i2c_master_general;

    reg clk;
    reg reset_n;
    reg start;
    reg [6:0] slave_addr;
    reg rw;
    reg [7:0] reg_addr;
    reg [15:0] w_data;
    reg multi_byte;

    wire [15:0] r_data;
    wire busy;
    wire ack_error;
    wire done;
    wire scl;
    wire sda;
    wire latch_start;
    wire [3:0] state;
    wire [3:0] slave_bit_cnt_wire; // use DUT bit_cnt

    // Pullup behavior for I2C
    pullup(sda);

    // ----------------------------------------
    // DUT
    // ----------------------------------------
    i2c_master_general #(.CLK_DIV(4)) DUT (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .reg_addr(reg_addr),
        .w_data(w_data),
        .multi_byte(multi_byte),
        .r_data(r_data),
        .busy(busy),
        .ack_error(ack_error),
        .done(done),
        .scl(scl),
        .sda(sda),
        .latch_start(latch_start),
        .state(state),
        .bit_cnt(slave_bit_cnt_wire) // connect DUT bit_cnt
    );

    // 100MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // =====================================================
    //              FIXED SLAVE MODEL
    // =====================================================
    reg sda_slave_drive;
    reg [15:0] read_data_word = 16'h3C3C; // multi-byte read

    assign sda = (sda_slave_drive) ? 1'b0 : 1'bz;

    // ---------- SDA Drive Logic (combinational) ----------
    // Remove your always @(*) combinational for SDA for ACK
    // Instead, drive SDA on negedge of DUT bit_cnt
    always @(negedge scl or negedge reset_n) begin
        if (!reset_n)
            sda_slave_drive <= 0;
        else begin
            // if bit_cnt == 0 on posedge of SCL, we are at last bit
            // drive ACK immediately for next SCL high
            if (slave_bit_cnt_wire == 0)
                sda_slave_drive <= 1'b1; // ACK is 0 on bus
            else if (rw) begin
                // DATA phase for reads
                sda_slave_drive <= ~read_data_word[7 - slave_bit_cnt_wire]; // MSB first
            end else
                sda_slave_drive <= 0; // release for writes
        end
    end

    // =====================================================
    // TEST SEQUENCE
    // =====================================================
    initial begin
        reset_n = 0;
        start = 0;
        slave_addr = 7'h48;
        reg_addr = 8'h10;
        w_data = 16'h55AA;
        multi_byte = 0;
        rw = 0;

        #50;
        reset_n = 1;

        // 1) WRITE
        $display("Starting single-byte WRITE...");
        multi_byte = 0;
        rw = 0;
        w_data = 16'h00AA;

        #20 start = 1;
        #10 start = 0;

        wait(done);

        if (!ack_error)
            $display("WRITE PASSED");
        else
            $display("WRITE FAILED (ACK ERROR)");

        #200;

        // 2) SINGLE READ
        $display("Starting single-byte READ...");
        multi_byte = 0;
        rw = 1;

        #20 start = 1;
        #10 start = 0;

        wait(done);

        if (r_data[7:0] == 8'h3C)
            $display("Single-byte READ PASSED");
        else
            $display("Single-byte READ FAILED: got %h", r_data);

        #200;

        // 3) MULTI READ
        $display("Starting multi-byte READ...");
        multi_byte = 1;
        rw = 1;

        #20 start = 1;
        #10 start = 0;

        wait(done);

        if (r_data == 16'h3C3C)
            $display("Multi-byte READ PASSED");
        else
            $display("Multi-byte READ FAILED: got %h", r_data);

        #500;
        $display("Simulation finished.");
        $stop;
    end

endmodule
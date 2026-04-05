`timescale 1ns / 1ps

module max_norm_3_axes #(
        // must have DATA_MSB <= DATA_LEN
        parameter int DATA_LEN  = 16,
        parameter int DATA_MSB  = 12
    )(
        // assumes 2's complement signed
        input   logic [DATA_LEN-1:0]    i_data_x,
        input   logic [DATA_LEN-1:0]    i_data_y,
        input   logic [DATA_LEN-1:0]    i_data_z,
        
        // max norm result
        output  logic [DATA_MSB-1:0]    o_data_max_norm
    );
    
    logic signed [DATA_LEN-1:0] sx, sy, sz;
    assign sx = signed'(i_data_x);
    assign sy = signed'(i_data_y);
    assign sz = signed'(i_data_z);
    
    // get absolute value
    logic [DATA_MSB-1:0] abs_x, abs_y, abs_z;
    assign abs_x = sx[DATA_MSB-1] ? DATA_MSB'(-sx[DATA_MSB-1:0]) : sx[DATA_MSB-1:0];
    assign abs_y = sy[DATA_MSB-1] ? DATA_MSB'(-sy[DATA_MSB-1:0]) : sy[DATA_MSB-1:0];
    assign abs_z = sz[DATA_MSB-1] ? DATA_MSB'(-sz[DATA_MSB-1:0]) : sz[DATA_MSB-1:0];
    
    // get max norm
    logic [DATA_MSB-1:0] max_norm;
    always_comb begin
        max_norm = abs_x;
        if (abs_y > max_norm) max_norm = abs_y;
        if (abs_z > max_norm) max_norm = abs_z;
    end
    
    assign o_data_max_norm = max_norm;
    
endmodule

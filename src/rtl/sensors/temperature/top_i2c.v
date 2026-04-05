`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2026 04:08:09 PM
// Design Name: 
// Module Name: top_i2c
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
// 
//////////////////////////////////////////////////////////////////////////////////
module top_i2c(
    input wire CLK100MHZ,   //100Mhz
    input wire reset,       //Reset button (active high)
    input wire start,       //BTNC
    input wire rw,          //BTND
    input wire [15:0] SW,   //Switches
    inout wire sda,         //PMOD JA  
    output wire scl,        //PMOD JA pin
    output wire [15:0] LED, //nexys 4 has 16 leds
    output wire LED16_B     //cmd_done
    );
    
    wire [15:0] read_data;
    wire [2:0] high_level_cmd;
    wire error;
    wire busy;
    wire [3:0] master_state;
    wire i2c_start_dbg;
    wire start_latched;
    wire cmd_start_latched;
    wire [3:0] bit_cnt;
    wire [7:0] data_addr_reg;
    wire [4:0] bit_phase;
    
    // Debug signals with MARK_DEBUG to ensure they're kept for ILA
    (* MARK_DEBUG = "TRUE" *) wire scl_drive_debug;
    (* MARK_DEBUG = "TRUE" *) wire sda_drive_debug;
    (* MARK_DEBUG = "TRUE" *) wire sda_in_debug;
    (* MARK_DEBUG = "TRUE" *) wire scl_calculated;
    (* MARK_DEBUG = "TRUE" *) wire sda_real;
    
    // Additional debug signals for data/control signals
    (* MARK_DEBUG = "TRUE" *) wire [15:0] debug_w_data;
    (* MARK_DEBUG = "TRUE" *) wire [15:0] debug_r_data;
    (* MARK_DEBUG = "TRUE" *) wire [6:0] debug_slave_addr;
    (* MARK_DEBUG = "TRUE" *) wire debug_multi_byte;
    (* MARK_DEBUG = "TRUE" *) wire debug_rw;
    (* MARK_DEBUG = "TRUE" *) wire [7:0] debug_reg_addr;
    (* MARK_DEBUG = "TRUE" *) wire debug_repeat_start;
    
    assign LED = read_data;
    assign high_level_cmd = SW[2:0]; 
        
    temp_sensor_driver u_temp(
        .clk(CLK100MHZ),
        .reset_n(~reset),
        .cmd_start(start),
        .rw(rw),
        .high_level_cmd(high_level_cmd),
        .cmd_value(SW),
        .cmd_done(LED16_B),
        .read_data(read_data),
        .error(error),
        .scl(scl), 
        .sda(sda),
        .busy(busy),
        .master_state(master_state),
        .start(i2c_start_dbg),
        .start_latched(start_latched),
        .cmd_start_latched(cmd_start_latched),
        .bit_cnt(bit_cnt),
        .bit_phase(bit_phase),
        .data_addr_reg(data_addr_reg),
        .scl_drive_debug(scl_drive_debug),
        .sda_drive_debug(sda_drive_debug),
        .sda_in_debug(sda_in_debug),
        .scl_calculated(scl_calculated),
        .sda_real(sda_real),
        .debug_w_data(debug_w_data),
        .debug_r_data(debug_r_data),
        .debug_slave_addr(debug_slave_addr),
        .debug_multi_byte(debug_multi_byte),
        .debug_rw(debug_rw),
        .debug_reg_addr(debug_reg_addr),
        .debug_repeat_start(debug_repeat_start)
    );
    
    // ILA with probes (0-13 existing + 6 new)
    ila_0 u_ila(
        .clk(CLK100MHZ),
        .probe0(scl_calculated),        // Calculated SCL (your command)
        .probe1(sda_real),              // REAL SDA bus voltage
        .probe2(scl_drive_debug),       // Master's SCL drive control
        .probe3(sda_drive_debug),       // Master's SDA drive control
        .probe4(master_state),          // FSM state
        .probe5(start),                 // Start signal
        .probe6(busy),                  // Master busy flag
        .probe7(LED16_B),               // Command done
        .probe8(sda_in_debug),          // SDA feedback (raw)
        .probe9(bit_cnt),               // Bit counter
        .probe10(bit_phase),            // Bit phase (0-5)
        .probe11(start_latched),        // Start latched
        .probe12(cmd_start_latched),    // Command start latched
        .probe13(debug_w_data),         // Write data
        .probe14(debug_r_data),         // Read data
        .probe15(debug_slave_addr),     // Slave address
        .probe16(debug_multi_byte),     // Multi-byte flag
        .probe17(debug_rw),             // R/W flag
        .probe18(debug_reg_addr),       // Register address
        .probe19(debug_repeat_start)    // Repeat start flag
    );
    
endmodule
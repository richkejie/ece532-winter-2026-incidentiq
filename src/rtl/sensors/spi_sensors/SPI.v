`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2026 09:45:03 AM
// Design Name: 
// Module Name: SPI
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


module SPI(
    input wire clk, 
    input wire reset, 
    input wire [15:0] in_data, 
    output reg [7:0] out_data, 
    input wire CTS, 
    output reg RTS, 
    output reg SCK,
    output reg CS_n,
    output reg MOSI, 
    input wire MISO, 
    input wire MODE // mode to be held low for 1 byte transfers followed by 1 byte read, mode to be held high for 2 byte transfers followed by 1 byte read. 
    );
    
    integer i; // used to count the clock 
    integer j; // used to iterate through the message the user wants to send 
    integer sendclockcounter; 
    reg [15:0] queued_data_to_send; // will capture the byte that the user wants to send over SPI
    reg sendflag; 
    reg SCK_p; // used to track when the SCK edges happen 
    reg SCK_n; // used to track when the SCK edges happen 
    reg reset_d; // delayed reset to be able to detect a falling edge 
    wire reset_fall = reset_d & ~reset; 
    reg done_sending; // signals that one last clock pulse is needed for the slave device to take in bits 
    reg mode_preserved; // captures what mode the user selected at the start of the transaction 
    reg program_config_flag_part1; // used to determine when we need to program the config register 
    reg program_config_flag_part2; // used to determine when we need to program the config register 
    
    reg program_config_flag_part1_gyro; // used to determine when we need to program the config register 
    reg program_config_flag_part2_gyro; // used to determine when we need to program the config register 
    
    reg [23:0] configuration1  = 24'b000010100010110010010011; 
    reg [23:0] configuration2  = 24'b000010100010110100100010; 
    
    reg [15:0] configuration3 = 16'b0010000011101111; 
    reg [15:0] configuration4 = 16'b0010001110000000; 
    wire sck_idle = (mode_preserved) ? 1'b0 : 1'b1;
    localparam integer CS_RISE_DLY = 3;   // sysclk after SCK posedge
    localparam integer CS_FALL_DLY = 6;   // sysclk after SCK posedge (must be < 10)
    
    reg [4:0] cs_gap_cnt;
    reg       end_delayflag;
    reg [4:0] cs_end_cnt;
    reg delayflag; 
    reg end_wait_rise_gyro;
    reg [23:0] boot_cnt = 24'd0;
    reg tx_prime_skip;  
    
    always @(posedge clk) begin 
        reset_d <= reset;
        if (reset) begin 
            RTS <= 0; 
            out_data <= 0; 
            i <= 0; 
            j <= 0; 
            SCK <= sck_idle; 
            mode_preserved <= MODE;
            CS_n <= 1; 
            sendflag <= 0; 
            MOSI <= 0;
            tx_prime_skip <= 1'b0;
            end_wait_rise_gyro <= 1'b0;
            boot_cnt <= 0; 
            delayflag <= 0; 
            cs_gap_cnt    <= 0;
            end_delayflag <= 0;
            cs_end_cnt    <= 0;
            reset_d <= 1;
            done_sending <= 0; 
            sendclockcounter <=0; 
            program_config_flag_part1 <= 0; 
            program_config_flag_part2 <= 0;
            program_config_flag_part1_gyro <= 0; 
            program_config_flag_part2_gyro <= 0;
        end else begin 
        
            SCK_p <= 0; // reset them here as well for safety
            SCK_n <= 0; // reset them here as well for safety 
            if (reset_fall) begin 
                cs_gap_cnt        <= 0;
                delayflag         <= 0;
                end_delayflag     <= 0;
                cs_end_cnt        <= 0;
                end_wait_rise_gyro<= 0;
                program_config_flag_part2 <= 0;
                program_config_flag_part2_gyro <= 0;
                if (!MODE) begin 
                   //RTS <= 1;  
                   program_config_flag_part1_gyro <= 1; 
                   program_config_flag_part1 <= 0; 
                   j <= 15; 
                end else begin 
                    program_config_flag_part1 <= 1; 
                    program_config_flag_part1_gyro <= 0; 
                    j <= 22; 
                end 
                 
                mode_preserved <= MODE;
            end 
         
        
        // firstly we need to configure the module after a reset to get the right resolution for the SPI device accelerometer
        
        else if (program_config_flag_part1 && MODE) begin 
            CS_n <= 0; // select the slave device
            
            if (j == 22) MOSI <= configuration1[23];  // pre load MOSI
            // generate the SCK
                
            if (i==9) begin 
                if (!SCK) begin 
                    SCK_p <= 1; // captured the posedge of SCK
                end 
                
                if (SCK) begin 
                    SCK_n <= 1; // captured the posedge of SCK
                end
                
                SCK <= ~SCK; 
                i <= 0; 
            end else begin 
                i <= i + 1; 
                SCK_p <= 0;
                SCK_n <= 0;
            end
            
            if (SCK_n) begin // shift out the input data on the negedge of the clock 
                if (j == 25) begin 
                    program_config_flag_part1 <= 0; // now that we have programmed the device to support the 8G standard
                    program_config_flag_part2 <= 1; // now that we have programmed the device to support the 8G standard
                    CS_n <= 1;
                    SCK  <= sck_idle;
                    j <= 22; 
                end else 
                if (j == 0) begin 
                    MOSI <= configuration1[j];
                    j <= 25; // some unused number for J 
                    
                    i <= 0; // reset the counter for this special case 
                      
                end else begin 
                    MOSI <= configuration1[j]; 
                    j <= j - 1; 
                end 
            end 
        
        end 
        
        else if (program_config_flag_part2 && MODE) begin 
            CS_n <= 0; // select the slave device 
            if (j == 22) MOSI <= configuration2[23];  // pre load MOSI
            // generate the SCK
                
            if (i==9) begin 
                if (!SCK) begin 
                    SCK_p <= 1; // captured the posedge of SCK
                end 
                
                if (SCK) begin 
                    SCK_n <= 1; // captured the posedge of SCK
                end
                
                SCK <= ~SCK; 
                i <= 0; 
            end else begin 
                i <= i + 1; 
                SCK_p <= 0;
                SCK_n <= 0;
            end
            
            if (SCK_n) begin // shift out the input data on the negedge of the clock 
                if (j == 25) begin 
                    program_config_flag_part1 <= 0; // now that we have programmed the device to support the 8G standard
                    program_config_flag_part2 <= 0; // now that we have programmed the device to support the 8G standard
                    CS_n <= 1;
                    SCK  <= sck_idle;
                    RTS <= 1; 
                end else 
                if (j == 0) begin 
                    MOSI <= configuration2[j];
                    j <= 25; // some unused number for J 
                    
                    i <= 0; // reset the counter for this special case 
                      
                end else begin 
                    MOSI <= configuration2[j]; 
                    j <= j - 1; 
                end 
            end 
        
        end 
        
        // firstly we need to configure the module after a reset to get the right resolution for the SPI device gyroscope device 
        
        else if (program_config_flag_part1_gyro && !MODE) begin 
            CS_n <= 0; // select the slave device 
            if (j == 15) MOSI <= configuration3[15];  // pre load MOSI
            // generate the SCK
                
            if (i==9) begin 
                if (!SCK) begin 
                    SCK_p <= 1; // captured the posedge of SCK
                end 
                
                if (SCK) begin 
                    SCK_n <= 1; // captured the posedge of SCK
                end
                
                SCK <= ~SCK; 
                i <= 0; 
            end else begin 
                i <= i + 1; 
                SCK_p <= 0;
                SCK_n <= 0;
            end

            if ((i==9) && (SCK==1'b1) && !end_wait_rise_gyro) begin
                MOSI <= configuration3[j];
                if (j == 0) begin
                    end_wait_rise_gyro <= 1'b1;  // last bit launched now wait for next rising edge
                end else begin
                    j <= j - 1;
                end
            end
            
            if (end_wait_rise_gyro && (i==9) && (SCK==1'b0)) begin
                end_wait_rise_gyro <= 1'b0;
            
                delayflag   <= 1'b1;  
                cs_gap_cnt  <= 0;
                
                program_config_flag_part1_gyro <= 1'b0;
                program_config_flag_part2_gyro <= 1'b1;
                
                j <= 15;               
            end
        
        end 
        
        else if (program_config_flag_part2_gyro && !MODE) begin
            SCK_p <= 0;
            SCK_n <= 0;
        
            if (delayflag) begin
                
                SCK <= sck_idle;
                i   <= 0;
        
                cs_gap_cnt <= cs_gap_cnt + 1;
   
                if (cs_gap_cnt == (CS_RISE_DLY-1)) begin
                    CS_n <= 1'b1;
                end
        
                if (cs_gap_cnt == (CS_FALL_DLY-1)) begin
                    CS_n       <= 1'b0;
                    delayflag  <= 1'b0;
                    cs_gap_cnt <= 0;
                    
                    SCK <= sck_idle;
                    i   <= 0;   
        
                    
                    j    <= 15;
                    MOSI <= configuration4[15];
                    end_wait_rise_gyro <= 1'b0;   
                end
            end
        
            else if (end_delayflag) begin
                
                SCK <= sck_idle;
                i   <= 0;
        
                cs_end_cnt <= cs_end_cnt + 1;
        
                if (cs_end_cnt == (CS_RISE_DLY-1)) begin
                    CS_n <= 1'b1;
                    RTS  <= 1'b1;
        
                    end_delayflag <= 1'b0;
                    cs_end_cnt    <= 0;
                    program_config_flag_part2_gyro <= 1'b0;
                end
            end
            else begin
                CS_n <= 1'b0;
        
                if (j == 15) begin
                    MOSI <= configuration4[15]; // pre load MSB
                end
        
                if (i == 9) begin
                    if (!SCK) SCK_p <= 1;  
                    if ( SCK) SCK_n <= 1;  
                    SCK <= ~SCK;
                    i   <= 0;
                end else begin
                    i <= i + 1;
                end
                if ((i==9) && (SCK==1'b1) && !end_wait_rise_gyro) begin
                    MOSI <= configuration4[j];
                    if (j == 0) begin
                        end_wait_rise_gyro <= 1'b1;  // last bit launched
                    end else begin
                        j <= j - 1;
                    end
                end
                if (end_wait_rise_gyro && (i==9) && (SCK==1'b0)) begin
                    end_wait_rise_gyro <= 1'b0;
        
                    end_delayflag <= 1'b1;
                    cs_end_cnt    <= 0;
                end
            end
        end
        // module assumes a 100MHz clock input - need to get this down to approx 5MHz for safety margin 
        
        else begin  
            SCK_p <= 0; // reset them here as well for safety
            SCK_n <= 0; // reset them here as well for safety 
            
            if (done_sending) begin 
                // logic for generating SCK in the duration of receiving a byte
                if (i==9) begin 
                   if (!SCK) begin 
                        SCK_p <= 1; // captured the posedge of SCK
                        
                       if (sendclockcounter > 1) begin // we have to capture each of the bits on the rising edge 
                        out_data[j] <= MISO; 
                        j <= j - 1; 
                       end 
                    end 
                    
                    if (SCK) begin 
                        SCK_n <= 1; // captured the posedge of SCK
                    end
                    SCK <= ~SCK; 
                    sendclockcounter <= sendclockcounter + 1; 
                    if (sendclockcounter == 19) begin 
                        SCK <= sck_idle;  
                        RTS <= 1; 
                        done_sending <= 0; 
                        CS_n <= 1; // terminate the transaction  
                        sendclockcounter <=0; 
                        
                    end 
                    i <= 0; 
                    
                end else begin  
                    i <= i + 1; 
                end     
            end else if (sendflag) begin 
            
                // generate the SCK
                
                if (i==9) begin 
                    if (!SCK) begin 
                        SCK_p <= 1; // captured the posedge of SCK
                    end 
                    
                    if (SCK) begin 
                        SCK_n <= 1; // captured the posedge of SCK
                    end
                    
                    SCK <= ~SCK; 
                    i <= 0; 
                end else begin 
                    i <= i + 1; 
                    SCK_p <= 0;
                    SCK_n <= 0;
                end
            end 
            
            if (sendflag && SCK_p && tx_prime_skip) begin
                tx_prime_skip <= 1'b0;
            end
            
            if (CTS && RTS) begin // sample the input data and get ready to shift it out 
                tx_prime_skip <= (sck_idle == 1'b1);
                CS_n <= 0; 
                queued_data_to_send <= in_data; 
                sendflag <= 1; 
                CS_n <= 0;
                if (mode_preserved) begin 
                    j <= 14; 
                    MOSI <= in_data[15]; // pre load MSB
                    
                end else begin 
                    j <= 6;
                    MOSI <= in_data[7]; // pre load MSB
                end
                RTS <= 0; // update to show that the module is busy 
                
                SCK <= sck_idle;
                i   <= 0;
                SCK_p <= 0;
                SCK_n <= 0;
            end 
            
            if (sendflag && SCK_n && !tx_prime_skip) begin
                if (j == 0) begin
                    MOSI <= queued_data_to_send[j];
                    j <= 7;
                    sendflag <= 0;
                    done_sending <= 1;
                    sendclockcounter <= 0;
                    i <= 0;
                end else begin
                    MOSI <= queued_data_to_send[j];
                    j <= j - 1;
                end
            end
        end 
    end
    
 end
    
    
endmodule


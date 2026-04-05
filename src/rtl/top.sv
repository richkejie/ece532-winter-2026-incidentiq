`timescale 1ns / 1ps

module top(
    input   logic           CLK,        // board clock crystal (100 MHZ?)
    input   logic           ARESET_N,    // reset button (async active low)
    
    input  wire BTNC,       // button for your FSM1/FSM2 reset behavior (PollingModule)
    
    // SPI0 physical pins (on-board accelerometer)
    input  wire MISO_0,
    output wire MOSI_0,
    output wire SCK_0,
    output wire CS_n_0,
    
    // SPI1 physical pins (gyroscope)
    input  wire MISO_1,
    output wire MOSI_1,
    output wire SCK_1,
    output wire CS_n_1,
    
    // I2C Temp sensor
    inout wire SDA,
    inout wire SCL,
    
    // GPS UART RX pin
    input  wire gps_rx,
    
    // LED outputs
    output  logic [1:0]     LED_CD_STATE,
    output  logic           LED_NON_FATAL_CRASH,
    output  logic           LED_FATAL_CRASH,
    output  logic           LED_CD_EN,
    output  logic           LED_CD_STATE_RST,
    output  logic           LED_BUFFER_FULL,
    output  logic           LED_BUFFER_EMPTY,
    
    // Bluetooth UART
    input  wire bt_uart_rxd,
    output wire bt_uart_txd,
    output wire bt_reset_gpio,
    
    // USB UART
    input usb_uart_rxd,
    output usb_uart_txd,
    
    // SD CARD SPI
    inout sd_card_spi_io0_io,
    inout sd_card_spi_io1_io,
    inout sd_card_spi_sck_io,
    inout [0:0]sd_card_spi_ss_io,
    
    // DDR memory
    output [12:0]DDR2_0_addr,
    output [2:0]DDR2_0_ba,
    output DDR2_0_cas_n,
    output [0:0]DDR2_0_ck_n,
    output [0:0]DDR2_0_ck_p,
    output [0:0]DDR2_0_cke,
    output [0:0]DDR2_0_cs_n,
    output [1:0]DDR2_0_dm,
    inout [15:0]DDR2_0_dq,
    inout [1:0]DDR2_0_dqs_n,
    inout [1:0]DDR2_0_dqs_p,
    output [0:0]DDR2_0_odt,
    output DDR2_0_ras_n,
    output DDR2_0_we_n
    );
    
    logic system_top_clk_out1;

    // --- LEDS ---
    logic [1:0]     w_cd_state;
    logic           w_non_fatal_crash_led, w_fatal_crash_led, w_cd_en_led, w_cd_state_reset_led;
    logic           w_buffer_full_led, w_buffer_empty_led;
    
    assign LED_CD_STATE         = w_cd_state;
    assign LED_NON_FATAL_CRASH  = w_non_fatal_crash_led;
    assign LED_FATAL_CRASH      = w_fatal_crash_led;
    assign LED_CD_EN            = w_cd_en_led;
    assign LED_CD_STATE_RST     = w_cd_state_reset_led;
    
    assign LED_BUFFER_FULL      = w_buffer_full_led;
    assign LED_BUFFER_EMPTY     = w_buffer_empty_led;
    
    // --- internal wires ---
    wire spi0_output_valid;
    wire spi1_output_valid;
    wire uart_valid;
    wire I2C_valid;

    wire [15:0] spi0_out_dataX, spi0_out_dataY, spi0_out_dataZ;
    wire [15:0] spi1_out_dataX, spi1_out_dataY, spi1_out_dataZ;
    wire [1023:0] out_sentence_captured;
    wire [15:0] I2C_output;
    
    logic           w_packet_valid;
    logic           w_data_recv;
    logic [15:0]    w_accel_z, w_accel_y, w_accel_x;
    logic [15:0]    w_gyro_z, w_gyro_y, w_gyro_x;
    logic [31:0]    w_gps_ground_speed;
    
    logic M_AXI_registers_s_axil_awready;
    logic M_AXI_registers_s_axil_awvalid;
    logic [31:0] M_AXI_registers_s_axil_awaddr;
    logic [2:0] M_AXI_registers_s_axil_awprot;
    logic M_AXI_registers_s_axil_wready;
    logic M_AXI_registers_s_axil_wvalid;
    logic [31:0] M_AXI_registers_s_axil_wdata;
    logic [3:0] M_AXI_registers_s_axil_wstrb;
    logic M_AXI_registers_s_axil_bready;
    logic M_AXI_registers_s_axil_bvalid;
    logic [1:0] M_AXI_registers_s_axil_bresp;
    logic M_AXI_registers_s_axil_arready;
    logic M_AXI_registers_s_axil_arvalid;
    logic [31:0] M_AXI_registers_s_axil_araddr;
    logic [2:0] M_AXI_registers_s_axil_arprot;
    logic M_AXI_registers_s_axil_rready;
    logic M_AXI_registers_s_axil_rvalid;
    logic [31:0] M_AXI_registers_s_axil_rdata;
    logic [1:0] M_AXI_registers_s_axil_rresp;

    registers_pkg::registers__in_t whwif_in;
    registers_pkg::registers__out_t whwif_out;

    logic [31:0] converted_M_AXI_registers_s_axil_awaddr, converted_M_AXI_registers_s_axil_araddr;

    logic [31:0] w_data_packet_bram_addr;
    logic [31:0] w_data_packet_bram_din;
    logic [3:0] w_data_packet_bram_we;
    logic w_data_packet_bram_en;
    
    logic w_gpio_cd_state_reset_tri_o;


    // --- register file ---
    registers u_reg_file(
        .clk(system_top_clk_out1),
        .arst_n(ARESET_N),
        .s_axil_awready(M_AXI_registers_s_axil_awready),
        .s_axil_awvalid(M_AXI_registers_s_axil_awvalid),
        .s_axil_awaddr(converted_M_AXI_registers_s_axil_awaddr),
        .s_axil_awprot(M_AXI_registers_s_axil_awprot),
        .s_axil_wready(M_AXI_registers_s_axil_wready),
        .s_axil_wvalid(M_AXI_registers_s_axil_wvalid),
        .s_axil_wdata(M_AXI_registers_s_axil_wdata),
        .s_axil_wstrb(M_AXI_registers_s_axil_wstrb),
        .s_axil_bready(M_AXI_registers_s_axil_bready),
        .s_axil_bvalid(M_AXI_registers_s_axil_bvalid),
        .s_axil_bresp(M_AXI_registers_s_axil_bresp),
        .s_axil_arready(M_AXI_registers_s_axil_arready),
        .s_axil_arvalid(M_AXI_registers_s_axil_arvalid),
        .s_axil_araddr(converted_M_AXI_registers_s_axil_araddr),
        .s_axil_arprot(M_AXI_registers_s_axil_arprot),
        .s_axil_rready(M_AXI_registers_s_axil_rready),
        .s_axil_rvalid(M_AXI_registers_s_axil_rvalid),
        .s_axil_rdata(M_AXI_registers_s_axil_rdata),
        .s_axil_rresp(M_AXI_registers_s_axil_rresp),
        .hwif_in(whwif_in),
        .hwif_out(whwif_out)
    );

    // --- system top ---
    system_top_wrapper u_system_top(
        .sys_clock(CLK),
        .cpu_reset_n(ARESET_N),
        .clk_out1(system_top_clk_out1),
        .M_AXI_registers_araddr(M_AXI_registers_s_axil_araddr),
        .M_AXI_registers_arprot(M_AXI_registers_s_axil_arprot),
        .M_AXI_registers_arready(M_AXI_registers_s_axil_arready),
        .M_AXI_registers_arvalid(M_AXI_registers_s_axil_arvalid),
        .M_AXI_registers_awaddr(M_AXI_registers_s_axil_awaddr),
        .M_AXI_registers_awprot(M_AXI_registers_s_axil_awprot),
        .M_AXI_registers_awready(M_AXI_registers_s_axil_awready),
        .M_AXI_registers_awvalid(M_AXI_registers_s_axil_awvalid),
        .M_AXI_registers_bready(M_AXI_registers_s_axil_bready),
        .M_AXI_registers_bresp(M_AXI_registers_s_axil_bresp),
        .M_AXI_registers_bvalid(M_AXI_registers_s_axil_bvalid),
        .M_AXI_registers_rdata(M_AXI_registers_s_axil_rdata),
        .M_AXI_registers_rready(M_AXI_registers_s_axil_rready),
        .M_AXI_registers_rresp(M_AXI_registers_s_axil_rresp),
        .M_AXI_registers_rvalid(M_AXI_registers_s_axil_rvalid),
        .M_AXI_registers_wdata(M_AXI_registers_s_axil_wdata),
        .M_AXI_registers_wready(M_AXI_registers_s_axil_wready),
        .M_AXI_registers_wstrb(M_AXI_registers_s_axil_wstrb),
        .M_AXI_registers_wvalid(M_AXI_registers_s_axil_wvalid),
        .crash_interrupt_in(w_non_fatal_crash_led),  // TODO
//        .crash_interrupt_in(BTNC),
        .data_packet_bram_port_addr(w_data_packet_bram_addr),
        .data_packet_bram_port_clk(system_top_clk_out1),
        .data_packet_bram_port_din(w_data_packet_bram_din),
        .data_packet_bram_port_dout(), // unconnected, data packager does not need to read from the buffer
        .data_packet_bram_port_en(w_data_packet_bram_en),
        .data_packet_bram_port_rst(ARESET_N),
        .data_packet_bram_port_we(w_data_packet_bram_we),
        .uart_rtl_0_rxd(bt_uart_rxd),
        .uart_rtl_0_txd(bt_uart_txd),
        .GPIO_0_tri_o(bt_reset_gpio),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd),
        .sd_card_spi_io0_io(sd_card_spi_io0_io),
        .sd_card_spi_io1_io(sd_card_spi_io1_io),
        .sd_card_spi_sck_io(sd_card_spi_sck_io),
        .sd_card_spi_ss_io(sd_card_spi_ss_io),
        .DDR2_0_addr(DDR2_0_addr),
        .DDR2_0_ba(DDR2_0_ba),
        .DDR2_0_cas_n(DDR2_0_cas_n),
        .DDR2_0_ck_n(DDR2_0_ck_n),
        .DDR2_0_ck_p(DDR2_0_ck_p),
        .DDR2_0_cke(DDR2_0_cke),
        .DDR2_0_cs_n(DDR2_0_cs_n),
        .DDR2_0_dm(DDR2_0_dm),
        .DDR2_0_dq(DDR2_0_dq),
        .DDR2_0_dqs_n(DDR2_0_dqs_n),
        .DDR2_0_dqs_p(DDR2_0_dqs_p),
        .DDR2_0_odt(DDR2_0_odt),
        .DDR2_0_ras_n(DDR2_0_ras_n),
        .DDR2_0_we_n(DDR2_0_we_n),
        .gpio_cd_state_reset_tri_o(w_gpio_cd_state_reset_tri_o)
    );

    assign converted_M_AXI_registers_s_axil_awaddr = { 16'b0, M_AXI_registers_s_axil_awaddr[15:0] };
    assign converted_M_AXI_registers_s_axil_araddr = { 16'b0, M_AXI_registers_s_axil_araddr[15:0] };

    // --- sensor polling ---
    PollingModule u_sensor_polling(
        .clk                (system_top_clk_out1),
        // .reset_top          (~ARESET_N),          // should change to async active low (is currently sync active high)
        .reset_top          (whwif_out.POLLING_EN.EN.value),
        
        .spi0_output_valid  (spi0_output_valid),
        .CS_n_0             (CS_n_0),
        .MOSI_0             (MOSI_0),
        .MISO_0             (MISO_0),
        .SCK_0              (SCK_0),
        
        .spi1_output_valid  (spi1_output_valid),
        .CS_n_1             (CS_n_1),
        .MOSI_1             (MOSI_1),
        .MISO_1             (MISO_1),
        .SCK_1              (SCK_1),
        
        .SDA                (SDA),
        .SCL                (SCL),
        
        .spi0_out_dataZ     (spi0_out_dataZ),
        .spi0_out_dataY     (spi0_out_dataY),
        .spi0_out_dataX     (spi0_out_dataX),
        
        .spi1_out_dataZ     (spi1_out_dataZ),
        .spi1_out_dataY     (spi1_out_dataY),
        .spi1_out_dataX     (spi1_out_dataX),
        
        .BTNC               (w_data_recv),
        
        .uart_valid         (uart_valid),
        .out_sentence_captured  (out_sentence_captured),
        .gps_rx             (gps_rx),

        .I2C_output         (I2C_output),
        .I2C_valid          (I2C_valid)
    );
    
    // --- data packager ---
    data_packager u_data_packager(
        .clk                (system_top_clk_out1),
        .arst_n             (ARESET_N),
        .ireg_dp_en         (whwif_out.DATA_PACAKGER_EN.EN.value),
        
        .i_accel_valid      (spi0_output_valid),
        .i_accel_z          (spi0_out_dataZ),
        .i_accel_y          (spi0_out_dataY),
        .i_accel_x          (spi0_out_dataX),
        
        .i_gps_valid        (uart_valid),
        .i_gps_sentence     (out_sentence_captured),
        
        .i_gyro_valid       (spi1_output_valid),
        .i_gyro_z           (spi1_out_dataZ),
        .i_gyro_y           (spi1_out_dataY),
        .i_gyro_x           (spi1_out_dataX),

        .i_temp_valid       (I2C_valid),
        .i_temp             (I2C_output),
        
        .o_data_recv        (w_data_recv),
        
        .o_packet           (), // not needed right now
        .o_packet_valid     (w_packet_valid),
        
        // BRAM interface
        .o_data_packet_bram_addr(w_data_packet_bram_addr),
        .o_data_packet_bram_din(w_data_packet_bram_din),
        .o_data_packet_bram_we(w_data_packet_bram_we),
        .o_data_packet_bram_en(w_data_packet_bram_en),

        .o_data_packet_bram_write_ptr(whwif_in.WRITE_PTR.WPTR.next),
        .o_data_packet_bram_status_empty(whwif_in.STATUS.EMPTY.next),
        .o_data_packet_bram_status_full(whwif_in.STATUS.FULL.next),
        .i_data_packet_bram_read_ptr(whwif_out.READ_PTR.RPTR.value),
        
        // crash detection interface
        .o_cd_accel_z       (w_accel_z),
        .o_cd_accel_y       (w_accel_y),
        .o_cd_accel_x       (w_accel_x),
        .o_cd_gyro_z        (w_gyro_z),
        .o_cd_gyro_y        (w_gyro_y),
        .o_cd_gyro_x        (w_gyro_x),
        .o_cd_gps_ground_speed(w_gps_ground_speed)
    );
    
    assign w_buffer_empty_led = whwif_in.STATUS.EMPTY.next;
    assign w_buffer_full_led = whwif_in.STATUS.FULL.next;
    
    // -- crash detection ---
    crash_detection u_crash_detection(
        .clk                (system_top_clk_out1),
        .arst_n             (ARESET_N),
//        .i_state_rst        (w_gpio_cd_state_reset_tri_o),
        .i_state_rst        (whwif_out.CD_STATE_RST.RST.value),
//        .i_sensors_valid    (w_packet_valid),
        .i_sensors_valid    (w_data_recv),
        
        .i_gps_ground_speed (w_gps_ground_speed),
        
        .i_accel_z          (w_accel_z),
        .i_accel_y          (w_accel_y),
        .i_accel_x          (w_accel_x),
        
        .i_gyro_z           (w_gyro_z),
        .i_gyro_y           (w_gyro_y),
        .i_gyro_x           (w_gyro_x),
        
        .ireg_speed_threshold                   (whwif_out.CD_SPEED_THRESH.THRESH.value),
        .ireg_non_fatal_accel_threshold         (whwif_out.CD_NON_FATAL_ACCEL_THRESH.THRESH.value),
        .ireg_fatal_accel_threshold             (whwif_out.CD_FATAL_ACCEL_THRESH.THRESH.value),
        .ireg_angular_speed_threshold           (whwif_out.CD_ANGULAR_SPEED_THRESH.THRESH.value),
        .ireg_cd_en                             (whwif_out.CD_EN.EN.value),
        
        .o_state            (w_cd_state),
        .o_non_fatal_intr   (w_non_fatal_crash_led),
        .o_fatal_intr       (w_fatal_crash_led)
    );
    
    assign w_cd_en_led = whwif_out.CD_EN.EN.value;
    assign w_cd_state_reset_led = w_gpio_cd_state_reset_tri_o;

    
endmodule

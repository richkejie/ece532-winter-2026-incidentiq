`timescale 1ns / 1ps
module nmea_field_extract #(
    parameter SENTENCE_BITS = 1024
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     start,
    input  logic [SENTENCE_BITS-1:0] sentence,
    output logic                     done,
    output logic                     busy,
    output logic [31:0]              utc_time,
    output logic [31:0]              latitude,
    output logic                     north,
    output logic [31:0]              longitude,
    output logic                     east,
    output logic [31:0]              ground_speed
);
    
    localparam NUM_BYTES    = SENTENCE_BITS / 8;
    localparam MAX_BYTE_IDX = NUM_BYTES - 1;
    localparam BYTE_IDX_W   = $clog2(NUM_BYTES + 1);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_PARSE,
        S_COMMIT_MUL,
        S_COMMIT_ADD,
        S_DONE
    } state_t;

    state_t state, state_next;

    // parsing state
    logic [BYTE_IDX_W-1:0] byte_idx,   byte_idx_next;
    logic [3:0]            field_idx,   field_idx_next;
    logic [31:0]           acc,         acc_next;
    logic [31:0]           frac_acc,    frac_acc_next;
    logic [31:0]           scale,       scale_next;
    logic [31:0]           frac_scale,  frac_scale_next;
    logic                  dot_seen,    dot_seen_next;

    // signals for multiplication step
    logic [31:0]           commit_acc,       commit_acc_next;
    logic [31:0]           commit_scale,     commit_scale_next;
    logic [31:0]           commit_frac_acc,  commit_frac_acc_next;
    logic [31:0]           commit_frac_scale, commit_frac_scale_next;
    logic [3:0]            commit_field_idx, commit_field_idx_next;

    // multiplication results for addition step
    logic [31:0]           mul_int,      mul_int_next;
    logic [31:0]           mul_frac,     mul_frac_next;

    // output registers
    logic [31:0] utc_time_next;
    logic [31:0] latitude_next;
    logic        north_next;
    logic [31:0] longitude_next;
    logic        east_next;
    logic [31:0] ground_speed_next;

    // current byte from sentence
    logic [7:0] cur_byte;
    assign cur_byte = sentence[8*byte_idx +: 8];

    // digit value
    logic [3:0] digit_val;
    assign digit_val = cur_byte[3:0];

    // character classification
    logic is_comma, is_dot, is_digit, is_N, is_E;
    assign is_comma = (cur_byte == 8'h2C);
    assign is_dot   = (cur_byte == 8'h2E);
    assign is_digit = (cur_byte >= 8'h30) && (cur_byte <= 8'h39);
    assign is_N     = (cur_byte == 8'h4E);
    assign is_E     = (cur_byte == 8'h45);

    always_comb begin
        // defaults: hold all values
        state_next      = state;
        byte_idx_next   = byte_idx;
        field_idx_next  = field_idx;
        acc_next        = acc;
        frac_acc_next   = frac_acc;
        scale_next      = scale;
        frac_scale_next = frac_scale;
        dot_seen_next   = dot_seen;

        commit_acc_next        = commit_acc;
        commit_scale_next      = commit_scale;
        commit_frac_acc_next   = commit_frac_acc;
        commit_frac_scale_next = commit_frac_scale;
        commit_field_idx_next  = commit_field_idx;

        mul_int_next  = mul_int;
        mul_frac_next = mul_frac;

        utc_time_next     = utc_time;
        latitude_next     = latitude;
        north_next        = north;
        longitude_next    = longitude;
        east_next         = east;
        ground_speed_next = ground_speed;

        case (state)
            S_IDLE: begin
                if (start) begin
                    state_next      = S_PARSE;
                    byte_idx_next   = '0;
                    field_idx_next  = 4'd0;
                    acc_next        = 32'd0;
                    frac_acc_next   = 32'd0;
                    scale_next      = 32'd10000;
                    frac_scale_next = 32'd10000;
                    dot_seen_next   = 1'b0;

                    commit_acc_next        = 32'd0;
                    commit_scale_next      = 32'd0;
                    commit_frac_acc_next   = 32'd0;
                    commit_frac_scale_next = 32'd0;
                    commit_field_idx_next  = 4'd0;

                    mul_int_next  = 32'd0;
                    mul_frac_next = 32'd0;

                    utc_time_next     = 32'd0;
                    latitude_next     = 32'd0;
                    north_next        = 1'b0;
                    longitude_next    = 32'd0;
                    east_next         = 1'b0;
                    ground_speed_next = 32'd0;
                end
            end

            S_PARSE: begin
                if (is_comma) begin
                    // registers for pipelined multiply
                    commit_acc_next        = acc;
                    commit_scale_next      = scale;
                    commit_frac_acc_next   = frac_acc;
                    commit_frac_scale_next = frac_scale;
                    commit_field_idx_next  = field_idx;

                    // advance field and reset accumulators
                    field_idx_next  = field_idx + 4'd1;
                    acc_next        = 32'd0;
                    frac_acc_next   = 32'd0;
                    dot_seen_next   = 1'b0;

                    // set scales for the NEXT field (field_idx + 1)
                    case (field_idx + 4'd1)
                        4'd1:       begin scale_next = 32'd1000;  frac_scale_next = 32'd1000;  end
                        4'd3, 4'd5: begin scale_next = 32'd10000; frac_scale_next = 32'd10000; end
                        4'd7:       begin scale_next = 32'd100;   frac_scale_next = 32'd100;   end
                        default:    begin scale_next = 32'd1;     frac_scale_next = 32'd1;     end
                    endcase

                    state_next = S_COMMIT_MUL;
                end else begin
                    case (field_idx)
                        4'd1, 4'd3, 4'd5, 4'd7: begin
                            if (is_dot)
                                dot_seen_next = 1'b1;
                            else if (is_digit) begin
                                if (!dot_seen) begin
                                    acc_next = acc * 10 + {28'd0, digit_val};
                                end else begin
                                    frac_acc_next = frac_acc * 10 + {28'd0, digit_val};
                                    case (frac_scale)
                                        32'd10000: frac_scale_next = 32'd1000;
                                        32'd1000:  frac_scale_next = 32'd100;
                                        32'd100:   frac_scale_next = 32'd10;
                                        32'd10:    frac_scale_next = 32'd1;
                                        default:   frac_scale_next = 32'd1;
                                    endcase
                                end
                            end
                        end
                        4'd4: if (is_N) north_next = 1'b1;
                        4'd6: if (is_E) east_next  = 1'b1;
                        default: ;
                    endcase

                    // advance byte index
                    if (byte_idx == MAX_BYTE_IDX[BYTE_IDX_W-1:0]) begin
                        state_next = S_DONE;
                    end else begin
                        byte_idx_next = byte_idx + 1;
                    end
                end
            end

            // compute the two multiplications
            S_COMMIT_MUL: begin
                mul_int_next  = commit_acc * commit_scale;
                mul_frac_next = commit_frac_acc * commit_frac_scale;
                state_next    = S_COMMIT_ADD;
            end

            // add products
            S_COMMIT_ADD: begin
                case (commit_field_idx)
                    4'd1: utc_time_next     = mul_int + mul_frac;
                    4'd3: latitude_next     = mul_int + mul_frac;
                    4'd5: longitude_next    = mul_int + mul_frac;
                    4'd7: ground_speed_next = mul_int + mul_frac;
                    default: ;
                endcase

                // check if we're done (past ground_speed field)
                if (field_idx > 4'd7) begin
                    state_next = S_DONE;
                end else if (byte_idx == MAX_BYTE_IDX[BYTE_IDX_W-1:0]) begin
                    state_next = S_DONE;
                end else begin
                    byte_idx_next = byte_idx + 1;
                    state_next = S_PARSE;
                end
            end

            S_DONE: begin
                state_next = S_IDLE;
            end

            default: state_next = S_IDLE;
        endcase
    end

    // sequential update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            byte_idx   <= '0;
            field_idx  <= 4'd0;
            acc        <= 32'd0;
            frac_acc   <= 32'd0;
            scale      <= 32'd10000;
            frac_scale <= 32'd10000;
            dot_seen   <= 1'b0;

            commit_acc        <= 32'd0;
            commit_scale      <= 32'd0;
            commit_frac_acc   <= 32'd0;
            commit_frac_scale <= 32'd0;
            commit_field_idx  <= 4'd0;

            mul_int  <= 32'd0;
            mul_frac <= 32'd0;

            utc_time     <= 32'd0;
            latitude     <= 32'd0;
            north        <= 1'b0;
            longitude    <= 32'd0;
            east         <= 1'b0;
            ground_speed <= 32'd0;
            done         <= 1'b0;
            busy         <= 1'b0;
        end else begin
            state      <= state_next;
            byte_idx   <= byte_idx_next;
            field_idx  <= field_idx_next;
            acc        <= acc_next;
            frac_acc   <= frac_acc_next;
            scale      <= scale_next;
            frac_scale <= frac_scale_next;
            dot_seen   <= dot_seen_next;

            commit_acc        <= commit_acc_next;
            commit_scale      <= commit_scale_next;
            commit_frac_acc   <= commit_frac_acc_next;
            commit_frac_scale <= commit_frac_scale_next;
            commit_field_idx  <= commit_field_idx_next;

            mul_int  <= mul_int_next;
            mul_frac <= mul_frac_next;

            utc_time     <= utc_time_next;
            latitude     <= latitude_next;
            north        <= north_next;
            longitude    <= longitude_next;
            east         <= east_next;
            ground_speed <= ground_speed_next;

            done <= (state_next == S_DONE);
            busy <= (state_next == S_PARSE) || (state_next == S_COMMIT_MUL) || (state_next == S_COMMIT_ADD);
        end
    end

endmodule
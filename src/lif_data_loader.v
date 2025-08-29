`timescale 1ns / 1ps
module iz_data_loader_lite (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire serial_data_in,
    input wire load_enable,
    output reg [5:0] param_a,  // Reduced from 8-bit to 6-bit
    output reg [5:0] param_b,  // Reduced from 8-bit to 6-bit
    output reg [5:0] param_c,  // Reduced from 8-bit to 6-bit
    output reg [5:0] param_d,  // Reduced from 8-bit to 6-bit
    output reg params_ready
);

// State machine states
localparam IDLE = 3'b000;
localparam LOAD_A = 3'b001;
localparam LOAD_B = 3'b010;
localparam LOAD_C = 3'b011;
localparam LOAD_D = 3'b100;
localparam READY = 3'b101;

// Internal registers - reduced bit width
reg [5:0] shift_reg;      // Reduced from 8-bit to 6-bit
reg [2:0] bit_count;
reg [2:0] state;
reg load_enable_prev;

// Edge detection
wire load_enable_rising = load_enable & ~load_enable_prev;

// Optimized default parameters (6-bit values)
localparam [5:0] DEFAULT_A = 6'd13;    // ~0.2 * 64
localparam [5:0] DEFAULT_B = 6'd13;    // ~0.2 * 64
localparam [5:0] DEFAULT_C = 6'd31;    // (~-65 + 96) scaled
localparam [5:0] DEFAULT_D = 6'd8;     // ~2 * 4

always @(posedge clk) begin
    if (reset) begin
        load_enable_prev <= 1'b0;
    end else begin
        load_enable_prev <= load_enable;
    end
end

// Parameter loading state machine
always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        shift_reg <= 6'd0;
        bit_count <= 3'd0;
        param_a <= DEFAULT_A;
        param_b <= DEFAULT_B;
        param_c <= DEFAULT_C;
        param_d <= DEFAULT_D;
        params_ready <= 1'b1;
    end else if (enable) begin
        case (state)
            IDLE: begin
                if (load_enable_rising) begin
                    state <= LOAD_A;
                    bit_count <= 3'd0;
                    shift_reg <= 6'd0;
                    params_ready <= 1'b0;
                end
            end
            
            LOAD_A: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[4:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd5) begin  // Load 6 bits
                        param_a <= {shift_reg[4:0], serial_data_in};
                        state <= LOAD_B;
                        bit_count <= 3'd0;
                        shift_reg <= 6'd0;
                    end
                end
            end
            
            LOAD_B: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[4:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd5) begin
                        param_b <= {shift_reg[4:0], serial_data_in};
                        state <= LOAD_C;
                        bit_count <= 3'd0;
                        shift_reg <= 6'd0;
                    end
                end
            end
            
            LOAD_C: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[4:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd5) begin
                        param_c <= {shift_reg[4:0], serial_data_in};
                        state <= LOAD_D;
                        bit_count <= 3'd0;
                        shift_reg <= 6'd0;
                    end
                end
            end
            
            LOAD_D: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[4:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd5) begin
                        param_d <= {shift_reg[4:0], serial_data_in};
                        state <= READY;
                        params_ready <= 1'b1;
                    end
                end
            end
            
            READY: begin
                if (load_enable_rising) begin
                    state <= LOAD_A;
                    bit_count <= 3'd0;
                    shift_reg <= 6'd0;
                    params_ready <= 1'b0;
                end else if (!load_enable) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end
endmodule

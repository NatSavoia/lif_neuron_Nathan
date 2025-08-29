`timescale 1ns / 1ps

module iz_data_loader_lite (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire serial_data_in,
    input wire load_enable,
    output reg [7:0] param_a,
    output reg [7:0] param_b,
    output reg [7:0] param_c, 
    output reg [7:0] param_d,
    output reg params_ready
);

// State machine (unchanged)
localparam IDLE = 3'b000;
localparam LOAD_A = 3'b001;
localparam LOAD_B = 3'b010;
localparam LOAD_C = 3'b011;
localparam LOAD_D = 3'b100;
localparam READY = 3'b101;

// Internal registers
reg [7:0] shift_reg;
reg [2:0] bit_count;
reg [2:0] state;
reg load_enable_prev;

// Edge detection
wire load_enable_rising = load_enable & ~load_enable_prev;

// Improved default parameters for better neuron diversity
// These are carefully chosen 8-bit values that maintain neuron characteristics
localparam [7:0] DEFAULT_A = 8'd26;      // 0.2 * 128 ? 26
localparam [7:0] DEFAULT_B = 8'd26;      // 0.2 * 128 ? 26  
localparam [7:0] DEFAULT_C = 8'd63;      // (-65 + 128) = 63 for proper encoding
localparam [7:0] DEFAULT_D = 8'd16;      // 2 * 8 = 16 for better scaling

always @(posedge clk) begin
    if (reset)
        load_enable_prev <= 1'b0;
    else
        load_enable_prev <= load_enable;
end

// Enhanced parameter loading with validation
always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        shift_reg <= 8'd0;
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
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                    $display("LOADER: Starting parameter loading");
                end
            end
            
            LOAD_A: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd7) begin
                        // Validate parameter A (should be positive and reasonable)
                        param_a <= ({shift_reg[6:0], serial_data_in} == 8'd0) ? 8'd1 : {shift_reg[6:0], serial_data_in};
                        state <= LOAD_B;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                        $display("LOADER: param_a loaded = %d", {shift_reg[6:0], serial_data_in});
                    end
                end
            end
            
            LOAD_B: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd7) begin
                        // Validate parameter B
                        param_b <= ({shift_reg[6:0], serial_data_in} == 8'd0) ? 8'd1 : {shift_reg[6:0], serial_data_in};
                        state <= LOAD_C;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                        $display("LOADER: param_b loaded = %d", {shift_reg[6:0], serial_data_in});
                    end
                end
            end
            
            LOAD_C: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd7) begin
                        param_c <= {shift_reg[6:0], serial_data_in};
                        state <= LOAD_D;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                        $display("LOADER: param_c loaded = %d", {shift_reg[6:0], serial_data_in});
                    end
                end
            end
            
            LOAD_D: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    
                    if (bit_count == 3'd7) begin
                        // Validate parameter D (should be positive)
                        param_d <= ({shift_reg[6:0], serial_data_in} == 8'd0) ? 8'd1 : {shift_reg[6:0], serial_data_in};
                        state <= READY;
                        params_ready <= 1'b1;
                        $display("LOADER: param_d loaded = %d", {shift_reg[6:0], serial_data_in});
                        $display("LOADER: All parameters loaded and validated!");
                    end
                end
            end
            
            READY: begin
                if (load_enable_rising) begin
                    state <= LOAD_A;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
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

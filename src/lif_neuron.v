`timescale 1ns / 1ps
module izh_neuron_lite (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [7:0] stimulus_in,
    input wire [5:0] param_a,  // Reduced from 8-bit to 6-bit
    input wire [5:0] param_b,  // Reduced from 8-bit to 6-bit
    input wire [5:0] param_c,  // Reduced from 8-bit to 6-bit
    input wire [5:0] param_d,  // Reduced from 8-bit to 6-bit
    input wire params_ready,
    output reg spike_out,
    output wire [7:0] membrane_out
);

// Reduced constants with smaller scale
localparam SCALE_SHIFT = 5;  // Reduced from 7 to 5
localparam SCALE = 32;       // 2^5 instead of 2^7
localparam signed [9:0] V_THRESH = 30 * SCALE;    // 960
localparam signed [9:0] V_REST = -70 * SCALE;     // -2240
localparam signed [9:0] CONST_140 = 140 * SCALE;  // 4480

// Drastically reduced state variables
reg signed [9:0] v;  // Reduced from 14-bit to 10-bit
reg signed [9:0] u;  // Reduced from 14-bit to 10-bit

// Simplified intermediate calculations
wire signed [19:0] v_squared = v * v;
wire signed [12:0] v_sq_term = (v_squared * 5) >>> 10;  // Simplified scaling
wire signed [12:0] v_5_term = (v << 2) + v;             // 5*v with shift-add
wire signed [12:0] stimulus_scaled = stimulus_in << SCALE_SHIFT;

// Simplified Izhikevich equations
wire signed [15:0] dv_calc = v_sq_term + v_5_term + CONST_140 - u + stimulus_scaled;
wire signed [12:0] bv_term = (param_b * v) >>> 3;       // Simplified scaling
wire signed [15:0] du_calc = (param_a * (bv_term - (u << 2))) >>> 4;

// Simple clamping function
function signed [9:0] clamp10;
    input signed [15:0] val;
    begin
        clamp10 = (val > 16'sd511) ? 10'sd511 : 
                 (val < -16'sd512) ? -10'sd512 : val[9:0];
    end
endfunction

wire signed [9:0] dv_limited = clamp10(dv_calc);
wire signed [9:0] du_limited = clamp10(du_calc);

// Spike detection
wire spike_detect = (v >= V_THRESH);

// Simplified membrane output
wire [7:0] membrane_calc = spike_detect ? 8'hFF : 
                          ((v - V_REST) >>> 2) + 8'd128;
assign membrane_out = membrane_calc;

// Simplified neuron dynamics
always @(posedge clk) begin
    if (reset) begin
        v <= V_REST;
        u <= 10'sd0;
        spike_out <= 1'b0;
    end else if (enable && params_ready) begin
        if (spike_detect) begin
            v <= V_REST + (param_c << 2);  // Simplified reset
            u <= u + (param_d << 1);       // Simplified recovery
            spike_out <= 1'b1;
        end else begin
            v <= v + (dv_limited >>> 1);   // Simplified integration
            u <= u + (du_limited >>> 2);   // Simplified recovery update
            spike_out <= 1'b0;
        end
    end else begin
        spike_out <= 1'b0;
    end
end
endmodule

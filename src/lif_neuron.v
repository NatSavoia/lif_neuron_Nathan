`timescale 1ns / 1ps
module izh_neuron_lite (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [7:0] stimulus_in,
    input wire [7:0] param_a,
    input wire [7:0] param_b,    
    input wire [7:0] param_c,
    input wire [7:0] param_d,
    input wire params_ready,
    output reg spike_out,
    output wire [7:0] membrane_out
);
    
// Scaling constants
localparam SCALE_SHIFT = 7;
localparam SCALE = 128;
localparam V_THRESH = 30 * SCALE;        
localparam V_REST   = -70 * SCALE;         
localparam CONST_140 = 140 * SCALE;      

// State variables
reg signed [13:0] v;  
reg signed [13:0] u;  

// v² and shift-add approx
wire signed [17:0] v_squared = v * v;
wire signed [18:0] v_sq_5x   = (v_squared <<< 2) + v_squared; 
wire signed [15:0] v_sq_term = v_sq_5x >>> (SCALE_SHIFT + 2);

wire signed [16:0] v_5x = (v <<< 2) + v;
wire signed [15:0] stimulus_scaled = stimulus_in <<< SCALE_SHIFT;

// 0.04 ≈ (1/32 + 1/128)
wire signed [15:0] v_sq_approx = (v_squared >>> 5) + (v_squared >>> 7);

// dv equation
wire signed [17:0] dv_calc = v_sq_approx + v_5x + CONST_140 - u + stimulus_scaled;

// Recovery (b*v - u)
wire signed [16:0] bv_term = (param_b[7:4] != 0) ? 
                             ($signed(param_b) * v) >>> 2 : 
                             (v * $signed({1'b0,param_b[3:0]})) >>> 2;

wire signed [16:0] recovery_diff = bv_term - (u <<< 3);   
wire signed [17:0] du_calc = ($signed(param_a) * recovery_diff) >>> 6;

// Clamp helper
function signed [13:0] clamp_14bit;
    input signed [17:0] val;
    begin
        if (val > 17'sd8191)
            clamp_14bit = 14'sd8191;
        else if (val < -17'sd8192)
            clamp_14bit = -14'sd8192;
        else
            clamp_14bit = val[13:0];  // truncated safely
    end
endfunction

wire signed [13:0] dv_limited = clamp_14bit(dv_calc);
wire signed [13:0] du_limited = clamp_14bit(du_calc);

// Spike detect + membrane
wire spike_detect = (v >= V_THRESH);
wire signed [12:0] v_norm = (v - V_REST) >>> 1;  
wire [7:0] membrane_calc = spike_detect ? 8'hFF : 
                           (v_norm < 0) ? 8'h00 : 
                           (v_norm > 255) ? 8'hFF : v_norm[7:0];
assign membrane_out = membrane_calc;

// Sequential neuron dynamics
always @(posedge clk) begin
    if (reset) begin
        v <= V_REST;
        u <= 14'sd0;
        spike_out <= 1'b0;
    end else if (enable && params_ready) begin
        if (spike_detect) begin
            v <= ($signed(param_c) <<< SCALE_SHIFT) - SCALE + V_REST;
            u <= u + ($signed(param_d) <<< 3);
            spike_out <= 1'b1;
        end else begin
            v <= v + (dv_limited >>> 3);
            u <= u + (du_limited >>> 3);
            spike_out <= 1'b0;
        end
    end else begin
        spike_out <= 1'b0;
    end
end
endmodule

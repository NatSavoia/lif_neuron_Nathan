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
localparam V_THRESH = 30 * SCALE;        // 3840
localparam V_REST   = -70 * SCALE;       // -8960
localparam CONST_140 = 140 * SCALE;      // 17920

// State variables
reg signed [13:0] v;
reg signed [13:0] u;

// --------------------------------------------------
// Pre-shifted signals (to avoid redundant shifters)
// --------------------------------------------------
wire signed [15:0] stimulus_scaled = stimulus_in <<< SCALE_SHIFT; 
wire signed [13:0] u_scaled8 = u <<< 3;    // used in recovery_diff

// --------------------------------------------------
// v² term (can share multiplier with others)
// --------------------------------------------------
wire signed [19:0] v_squared_full = v * v;
wire signed [15:0] v_sq_term = (v_squared_full * 5) >>> (SCALE_SHIFT + 2);

// --------------------------------------------------
// 5v as shift+add
// --------------------------------------------------
wire signed [13:0] v_term = (v <<< 2) + v;

// --------------------------------------------------
// dv_full computation with balanced adds
// --------------------------------------------------
wire signed [19:0] dv_full;
wire signed [19:0] base_sum = v_sq_term + v_term; 
assign dv_full = base_sum + CONST_140 + stimulus_scaled - u;

// --------------------------------------------------
// du_full computation
// --------------------------------------------------
wire signed [19:0] bv_scaled = (param_b * v) >>> 2;
wire signed [19:0] recovery_diff = bv_scaled - u_scaled8;
wire signed [19:0] du_full = (param_a * recovery_diff) >>> 6;

// --------------------------------------------------
// Saturating clamp for dv_limited
// --------------------------------------------------
wire signed [13:0] dv_tmp = dv_full[13:0];
wire overflow_pos_dv = (dv_full[19:14] != 0);
wire overflow_neg_dv = (dv_full[19:14] != {6{dv_full[13]}});
wire signed [13:0] dv_limited = overflow_pos_dv ? 14'sd8191 :
                                overflow_neg_dv ? -14'sd8192 :
                                dv_tmp;

// --------------------------------------------------
// Saturating clamp for du_limited
// --------------------------------------------------
wire signed [13:0] du_tmp = du_full[13:0];
wire overflow_pos_du = (du_full[19:14] != 0);
wire overflow_neg_du = (du_full[19:14] != {6{du_full[13]}});
wire signed [13:0] du_limited = overflow_pos_du ? 14'sd4095 :
                                overflow_neg_du ? -14'sd4096 :
                                du_tmp;

// --------------------------------------------------
// Pre-shift step values for update
// --------------------------------------------------
wire signed [13:0] dv_step = dv_limited >>> 4;
wire signed [13:0] du_step = du_limited >>> 4;

// --------------------------------------------------
// Membrane output scaling
// --------------------------------------------------
wire spike_detect = (v >= V_THRESH);
wire signed [13:0] v_normalized = v - V_REST;
wire signed [15:0] membrane_scaled = (v_normalized * 256) >>> SCALE_SHIFT;
assign membrane_out = spike_detect ? 8'hFF : 
                     (membrane_scaled < 0) ? 8'h00 : 
                     (membrane_scaled > 255) ? 8'hFF : membrane_scaled[7:0];

// --------------------------------------------------
// Sequential block
// --------------------------------------------------
always @(posedge clk) begin
    if (reset) begin
        v <= V_REST;
        u <= 14'sd0;
        spike_out <= 1'b0;
    end else if (enable && params_ready) begin
        if (spike_detect) begin
            // Reset after spike
            v <= (param_c <<< SCALE_SHIFT) + (V_REST - (128 <<< SCALE_SHIFT));
            u <= u + (param_d <<< 4);
            spike_out <= 1'b1;
        end else begin
            v <= v + dv_step;
            u <= u + du_step;
            spike_out <= 1'b0;
        end
    end else begin
        spike_out <= 1'b0;
    end
end

endmodule

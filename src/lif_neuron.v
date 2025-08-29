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
    
// Improved scaling - using 2^7 = 128 for better precision vs resources
localparam SCALE_SHIFT = 7;
localparam SCALE = 128;
localparam V_THRESH = 30 * SCALE;        // 30mV * 128 = 3840
localparam V_REST = -70 * SCALE;         // -70mV * 128 = -8960
localparam CONST_140 = 140 * SCALE;      // 140 * 128 = 17920

// Increased precision state variables (14-bit for better dynamics)
reg signed [13:0] v;  // Membrane potential  
reg signed [13:0] u;  // Recovery variable

// Improved intermediate calculations
wire signed [19:0] v_squared_full;       // Full v² calculation
wire signed [15:0] v_sq_term;            // Scaled 0.04v² term
wire signed [15:0] stimulus_scaled;      // Scaled stimulus
wire signed [19:0] dv_full;              // Full dv calculation  
wire signed [19:0] du_full;              // Full du calculation
wire signed [13:0] dv_limited, du_limited;

// Spike detection
wire spike_detect = (v >= V_THRESH);

// Improved IZ equation with better v² approximation
assign v_squared_full = v * v;
// Better 0.04 approximation: 0.04 ? 5/128 (more accurate than shift-only)
assign v_sq_term = (v_squared_full * 5) >>> (SCALE_SHIFT + 2);

// Scale stimulus input  
assign stimulus_scaled = stimulus_in << SCALE_SHIFT;

// Full IZ equation: dv = 0.04v² + 5v + 140 - u + I
assign dv_full = v_sq_term +                         // 0.04v² term
                (v * 5) +                            // 5v term  
                CONST_140 -                          // 140 constant
                u +                                  // -u term
                stimulus_scaled;                     // +I term

// Improved recovery dynamics: du = a(bv - u) with better scaling
wire signed [19:0] bv_scaled = (param_b * v) >>> 2;        // Scale b*v
wire signed [19:0] recovery_diff = bv_scaled - (u << 3);   // b*v - u with scaling
assign du_full = (param_a * recovery_diff) >>> 6;          // a * (b*v - u)

// Improved clamping to prevent overflow
assign dv_limited = (dv_full > 14'sd8191) ? 14'sd8191 : 
                   (dv_full < -14'sd8192) ? -14'sd8192 : dv_full[13:0];
                   
assign du_limited = (du_full > 14'sd4095) ? 14'sd4095 : 
                   (du_full < -14'sd4096) ? -14'sd4096 : du_full[13:0];

// Fixed membrane output with proper dynamic range
wire signed [13:0] v_normalized = v - V_REST;
wire signed [15:0] membrane_scaled = (v_normalized * 256) >>> SCALE_SHIFT;
assign membrane_out = spike_detect ? 8'hFF : 
                     (membrane_scaled < 0) ? 8'h00 : 
                     (membrane_scaled > 255) ? 8'hFF : membrane_scaled[7:0];

// Enhanced neuron dynamics with parameter-sensitive reset
always @(posedge clk) begin
    if (reset) begin
        v <= V_REST;
        u <= 14'sd0;
        spike_out <= 1'b0;
    end else if (enable && params_ready) begin
        if (spike_detect) begin
            // Improved IZ reset with proper parameter scaling
            v <= ((param_c - 8'd128) << SCALE_SHIFT) + V_REST;  // c scaled properly
            u <= u + (param_d << 4);                            // d scaled for recovery
            spike_out <= 1'b1;
        end else begin
            // Integrate with adaptive timestep based on membrane potential
            v <= v + (dv_limited >>> 4);             // Smaller dt for stability
            u <= u + (du_limited >>> 4);
            spike_out <= 1'b0;
        end
    end else begin
        spike_out <= 1'b0;
    end
end

endmodule

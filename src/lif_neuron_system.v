`timescale 1ns / 1ps
module izh_neuron_system_lite (
    input wire clk,
    input wire reset,
    input wire enable,
    
    // 8 Input pins
    input wire [7:0] stimulus_in,
    
    // 8 Output pins  
    output wire [7:0] membrane_out,
    
    // 8 Inout pins
    inout wire input_enable,
    inout wire load_mode,
    inout wire serial_data,
    inout wire spike_out,
    inout wire params_ready,
    inout wire [2:0] debug_state
);
    
    // Internal wiring
    wire internal_input_enable = input_enable;
    wire internal_load_mode = load_mode;
    wire internal_serial_data = serial_data;
    
    wire [5:0] internal_param_a, internal_param_b, internal_param_c, internal_param_d;
    wire loader_params_ready;
    wire neuron_spike_out;
    
    // Drive output inout pins
    assign spike_out = neuron_spike_out;
    assign params_ready = loader_params_ready;
    assign debug_state = 3'b000;  // Simple debug state
    
    // Enhanced data loader with reduced bit width
    iz_data_loader_lite loader (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .serial_data_in(internal_serial_data),
        .load_enable(internal_load_mode),
        .param_a(internal_param_a),
        .param_b(internal_param_b),
        .param_c(internal_param_c),
        .param_d(internal_param_d),
        .params_ready(loader_params_ready)
    );
    
    // Enhanced neuron core with reduced bit width
    izh_neuron_lite neuron (
        .clk(clk),
        .reset(reset),
        .enable(enable & internal_input_enable),
        .stimulus_in(stimulus_in),
        .param_a(internal_param_a),
        .param_b(internal_param_b),
        .param_c(internal_param_c),
        .param_d(internal_param_d),
        .params_ready(loader_params_ready),
        .spike_out(neuron_spike_out),
        .membrane_out(membrane_out)
    );
endmodule

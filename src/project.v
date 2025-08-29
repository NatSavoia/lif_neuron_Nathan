/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tt_um_izh_neuron_lite (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Internal signals for system interface
    wire reset = ~rst_n;           // Convert active-low reset to active-high
    wire enable = ena;             // Use enable signal
    
    // Input signal assignments from TinyTapeout interface
    wire [7:0] stimulus_in = ui_in; // 8-bit stimulus input directly mapped
    
    // Internal output wires from system module
    wire [7:0] membrane_out;
    
    // Bidirectional signal management
    wire input_enable_in = uio_in[0];
    wire load_mode_in = uio_in[1]; 
    wire serial_data_in = uio_in[2];
    
    wire spike_out_internal;
    wire params_ready_internal;
    wire [2:0] debug_state_internal;
    
    // Izhikevich neuron system instantiation
    izh_neuron_system_lite system_inst (
        // System signals
        .clk(clk),
        .reset(reset),
        .enable(enable),
        
        // 8 Input pins
        .stimulus_in(stimulus_in),
        
        // 8 Output pins  
        .membrane_out(membrane_out),
        
        // 8 Inout pins (handled as separate input/output)
        .input_enable(input_enable_in),
        .load_mode(load_mode_in),
        .serial_data(serial_data_in),
        .spike_out(spike_out_internal),
        .params_ready(params_ready_internal),
        .debug_state(debug_state_internal)
    );
    
    // Output signal assignments to TinyTapeout interface
    assign uo_out = membrane_out;           // 8-bit membrane potential output
    
    // Bidirectional I/O configuration
    assign uio_out[0] = spike_out_internal;         // Spike output
    assign uio_out[1] = params_ready_internal;      // Parameter ready status
    assign uio_out[4:2] = debug_state_internal;     // 3-bit debug state
    assign uio_out[7:5] = 3'b0;                     // Unused outputs set to 0
    
    // Set bidirectional pin directions
    assign uio_oe[0] = 1'b1;                // spike_out as output
    assign uio_oe[1] = 1'b1;                // params_ready as output  
    assign uio_oe[4:2] = 3'b111;            // debug_state as outputs
    assign uio_oe[7:5] = 3'b0;              // unused pins as inputs
    
    // List unused inputs to prevent warnings
    wire _unused = &{uio_in[7:3], 1'b0};

endmodule

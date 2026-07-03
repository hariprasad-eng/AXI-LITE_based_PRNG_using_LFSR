// ============================================================
// Module  : lfsr_core
// Project : AXI-Lite PRNG RTL2GDS
// Description:
//   4-bit Galois LFSR (Linear Feedback Shift Register)
//   Tap positions : [4, 0]  → polynomial x^4 + x^3 + 1
//   Maximum-length sequence: 2^4 - 1 = 15 unique states
//
//   Operation:
//     - Active-low synchronous reset; loads 'seed' value
//     - When enable=1, shifts every rising clock edge
//     - Output 'rand_out' holds current 4-bit random value
//
//   Feedback:
//     new_bit = rand_out[3] XOR rand_out[2]
//     shift  : {rand_out[2:0], new_bit}
// ============================================================

module lfsr_core (
    input  wire       clk,       // System clock
    input  wire       rst_n,     // Active-low synchronous reset
    input  wire       enable,    // Enable shifting (1 = run)
    input  wire [3:0] seed,      // Seed value loaded on reset
    output reg  [3:0] rand_out   // Current pseudo-random value
);

    // --------------------------------------------------------
    // Internal signal
    // --------------------------------------------------------
    wire feedback;

    // Galois LFSR feedback: XOR of tap positions 4 and 1
    // (bit indices 3 and 0 in 0-based)
    assign feedback = rand_out[3] ^ rand_out[0];

    // --------------------------------------------------------
    // Sequential logic : shift register
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            // Load seed on reset; never allow all-zero state
            rand_out <= (seed == 4'b0000) ? 4'b0001 : seed;
        end
        else if (enable) begin
            // Shift left and insert feedback at LSB
            rand_out <= {rand_out[2:0], feedback};
        end
        // else: hold current value
    end

endmodule

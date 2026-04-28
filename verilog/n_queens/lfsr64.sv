`ifndef LFSR64_SV
`define LFSR64_SV

module lfsr64 (
    input  logic        clk,
    input  logic        rst,
    input  logic        enable,
    output logic [63:0] state
);

    // Galois LFSR with taps at 63, 62, 60, 59
    // Feedback: state[63] ^ state[62] ^ state[60] ^ state[59]

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 64'h123456789ABCDEF;  // Default seed
        end else if (enable) begin
            // Calculate feedback
            logic feedback;
            feedback = state[63] ^ state[62] ^ state[60] ^ state[59];

            // Shift right and insert feedback at MSB
            state <= {feedback, state[63:1]};
        end
    end

endmodule

`endif // LFSR64_SV

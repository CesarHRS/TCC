`ifndef LFSR64_SV
`define LFSR64_SV

module lfsr64 (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    output wire [63:0] state
);

    // Galois LFSR with taps at 63, 62, 60, 59
    // Feedback: state[63] ^ state[62] ^ state[60] ^ state[59]

    reg [63:0] state_reg;
    assign state = state_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_reg <= 64'h123456789ABCDEF;  // Default seed
        end else if (enable) begin
            // Calculate feedback
            reg feedback;
            feedback = state_reg[63] ^ state_reg[62] ^ state_reg[60] ^ state_reg[59];

            // Shift right and insert feedback at MSB
            state_reg <= {feedback, state_reg[63:1]};
        end
    end

endmodule

`endif // LFSR64_SV

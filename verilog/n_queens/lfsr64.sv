// LFSR de 64 bits — polinômio x^64 + x^63 + x^61 + x^60 + 1
// Taps nos bits 63, 62, 60, 59. Idêntico ao LFSR64 do software (cpp/n_queens/lfsr64.h).
// Semente fixa 0xDEADBEEFCAFEBABE em reset, igual ao C++.
//
// Cada ciclo com `enable` alto produz um novo estado (shift left + novo bit no LSB).

module lfsr64 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    output reg  [63:0] state
);

    wire new_bit = state[63] ^ state[62] ^ state[60] ^ state[59];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= 64'hDEAD_BEEF_CAFE_BABE;
        else if (enable)
            state <= {state[62:0], new_bit};
    end

endmodule

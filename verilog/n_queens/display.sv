module display (
    input  wire [3:0] hex_digit,
    output wire [6:0] segments
);
    reg [6:0] segments_reg;
    assign segments = segments_reg;
    
    always @(*) begin
        case (hex_digit)
            4'h0: segments_reg = 7'b1000000;
            4'h1: segments_reg = 7'b1111001;
            4'h2: segments_reg = 7'b0100100;
            4'h3: segments_reg = 7'b0110000;
            4'h4: segments_reg = 7'b0011001;
            4'h5: segments_reg = 7'b0010010;
            4'h6: segments_reg = 7'b0000010;
            4'h7: segments_reg = 7'b1111000;
            4'h8: segments_reg = 7'b0000000;
            4'h9: segments_reg = 7'b0010000;
            default: segments_reg = 7'b1111111;
        endcase
    end
endmodule

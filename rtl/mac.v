`timescale 1ns/1ps
module mac(
    input         clk,
    input         reset,
    input         run,
    input         acc_clear,
    input  signed [7:0]  weight,
    input  signed [7:0]  activation,
    output reg signed [31:0] out
);

    wire [15:0]mul;

    assign mul = weight*activation;

    always @(posedge clk) begin
        if (reset || acc_clear) begin
            out <= 32'b0;
        end
        else begin
            if (run) begin
                out <= out + {{16{mul[15]}}, mul};
            end
        end
    end

endmodule

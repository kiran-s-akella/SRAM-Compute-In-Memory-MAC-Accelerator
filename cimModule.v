`timescale 1ns/1ps
module cimModule(
    input clk, csb, web, reset, run, acc_clear,
    input      [9:0] addr,
    input      [7:0] din,
    input      [7:0] din2, //this is for the data which comes from the activation sram
    output     [31:0] mac_out //mac output
);

    wire [7:0] dout;

    sky130_sram_1kbyte_1rw1r_8x1024_8 module1(
        .clk0(clk),
        .csb0(csb),
        .web0(web),
        .wmask0(1'b1),
        .addr0(addr),
        .din0(din),
        .dout0(dout),
        .clk1(1'b0),
        .csb1(1'b0),
        .addr1(10'b0),
        .dout1()
    );

    mac module2(
        .clk(clk),
        .reset(reset),
        .run(run),
        .weight(dout),
        .activation(din2),
        .acc_clear(acc_clear),
        .out(mac_out)
    );


endmodule
`timescale 1ns/1ps
module cimArray(
    input         clk,
    input         reset,
    input         start_flag,
    input         change_act,
    input  [7:0]  data_in,
    output [319:0]mac_output,
    output        done
);

    wire [7:0]act_out;
    reg [10:0]csb;
    reg [10:0]web;
    reg run, acc_clear;

    reg [9:0]ctr, ctr_d;

    reg [3:0]state, nextState;
    localparam IDLE    = 4'b0000,
               WEIGHT0 = 4'b0001,
               WEIGHT1 = 4'b0010,
               WEIGHT2 = 4'b0011,
               WEIGHT3 = 4'b0100,
               WEIGHT4 = 4'b0101,
               WEIGHT5 = 4'b0110,
               WEIGHT6 = 4'b0111,
               WEIGHT7 = 4'b1000,
               WEIGHT8 = 4'b1001,
               WEIGHT9 = 4'b1010,
               ACT     = 4'b1011,
               CALC    = 4'b1100,
               DONE    = 4'b1101;

    genvar i;
    generate //these are the cim modules
        for (i = 0; i < 10; i = i+1) begin: cimModule_loop
            cimModule cm(
                .clk(clk),
                .reset(reset),
                .run(run),
                .csb(csb[i]),
                .web(web[i]),
                .addr(ctr),
                .din(data_in),
                .din2(act_out),
                .acc_clear(acc_clear),
                .mac_out(mac_output[32*i + 31 : 32*i])
            );
        end
    endgenerate
    
    sky130_sram_1kbyte_1rw1r_8x1024_8 module1( //this is the sram for activation data
        .clk0(clk),
        .csb0(csb[10]),
        .web0(web[10]),
        .wmask0(1'b1),
        .addr0(ctr),
        .din0(data_in),
        .dout0(act_out),
        .clk1(1'b0),
        .csb1(1'b0),
        .addr1(10'b0),
        .dout1()
    );

    reg calc_active_d;
    assign done = (state == DONE);
    
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            ctr <= 10'b0;
            ctr_d <= 10'b0;
        end
        else begin
            state <= nextState;
            if (nextState == WEIGHT0 || nextState == ACT)
                ctr <= 10'b0; 
            if (state > IDLE && state < DONE) //very bad way of writing this
                ctr <= ctr+1;
            ctr_d <= ctr;
            calc_active_d <= (state == CALC);
        end
    end

    always @(*) begin
        csb = 11'b11111111111;
        web = 11'b11111111111;
        run = 1'b0;
        nextState = IDLE;
        acc_clear = 1'b0;
        case (state)
            IDLE: begin
                if (start_flag)
                    nextState = WEIGHT0;
                else
                    nextState = IDLE;
            end

            WEIGHT0: begin
                csb = 11'b11111111110;
                web = 11'b11111111110;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT1;
                else 
                    nextState = WEIGHT0;
            end

            WEIGHT1: begin
                csb = 11'b11111111101;
                web = 11'b11111111101;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT2;
                else 
                    nextState = WEIGHT1;
            end

            WEIGHT2: begin
                csb = 11'b11111111011;
                web = 11'b11111111011;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT3;
                else 
                    nextState = WEIGHT2;
            end
            
            WEIGHT3: begin
                csb = 11'b11111110111;
                web = 11'b11111110111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT4;
                else 
                    nextState = WEIGHT3;
            end

            WEIGHT4: begin
                csb = 11'b11111101111;
                web = 11'b11111101111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT5;
                else 
                    nextState = WEIGHT4;
            end

            WEIGHT5: begin
                csb = 11'b11111011111;
                web = 11'b11111011111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT6;
                else 
                    nextState = WEIGHT5;
            end

            WEIGHT6: begin
                csb = 11'b11110111111;
                web = 11'b11110111111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT7;
                else 
                    nextState = WEIGHT6;
            end

            WEIGHT7: begin
                csb = 11'b11101111111;
                web = 11'b11101111111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT8;
                else 
                    nextState = WEIGHT7;
            end

            WEIGHT8: begin
                csb = 11'b11011111111;
                web = 11'b11011111111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = WEIGHT9;
                else 
                    nextState = WEIGHT8;
            end

            WEIGHT9: begin
                csb = 11'b10111111111;
                web = 11'b10111111111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = ACT;
                else 
                    nextState = WEIGHT9;
            end

            ACT: begin
                csb = 11'b01111111111;
                web = 11'b01111111111;
                run = 1'b0;
                if (ctr == 1023)
                    nextState = CALC;
                else 
                    nextState = ACT;
            end

            CALC: begin
                csb = 11'b00000000000;
                web = 11'b11111111111;
                run = calc_active_d;
                acc_clear = (state == CALC) && !calc_active_d;
                if (calc_active_d && ctr_d == 1023)
                    nextState = DONE;
                else 
                    nextState = CALC;
            end

            DONE: begin
                csb = 11'b11111111111;
                web = 11'b11111111111;
                run = 1'b0;
                if (change_act)
                    nextState = ACT;
                else 
                    nextState = DONE;
            end
        endcase
    end

endmodule

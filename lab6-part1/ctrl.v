module ctrl #(
    parameter IN_WIDTH = 8,
    parameter OUT_WIDTH = 16,
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter MULT_LAT = 1,
    parameter ACC_LAT = 1
)(
    input clk,
    input rst,
    input input_rst_accumulator,
    input input_stream_out_rdy,
    output [COLS-1:0] rst_accumulator,
    output [COLS-1:0] stream_out_rdy
);

    // Column 0 receives the signals immediately
    assign rst_accumulator[0] = input_rst_accumulator;
    assign stream_out_rdy[0]  = input_stream_out_rdy;

    // Subsequent columns receive signals delayed by MULT_LAT cycles per column
    generate
        for (i = 1; i < COLS; i = i + 1) begin : shift_gen
            reg [MULT_LAT-1:0] rst_acc_delay_reg;
            reg [MULT_LAT-1:0] stream_rdy_delay_reg;
            
            always @(posedge clk) begin
                if (rst) begin
                    rst_acc_delay_reg    <= {MULT_LAT{1'b0}};
                    stream_rdy_delay_reg <= {MULT_LAT{1'b0}};
                end else begin
                    rst_acc_delay_reg    <= {rst_acc_delay_reg[MULT_LAT-2:0], rst_accumulator[i-1]};
                    stream_rdy_delay_reg <= {stream_rdy_delay_reg[MULT_LAT-2:0], stream_out_rdy[i-1]};
                end
            end
            
            assign rst_accumulator[i] = rst_acc_delay_reg[MULT_LAT-1];
            assign stream_out_rdy[i]  = stream_rdy_delay_reg[MULT_LAT-1];
        end
    endgenerate

endmodule
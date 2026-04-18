module ctrl #(
    parameter IN_WIDTH = 8,
    parameter OUT_WIDTH = 16,
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter MULT_LAT = 1,
    parameter ACC_LAT = 1, 
    parameter K = 4 
)(
    input clk,
    input rst,
    input input_rst_accumulator,
    input input_stream_out_rdy,
    output [COLS-1:0] rst_accumulator,
    output [COLS-1:0] stream_out_rdy
);

    //TODO: Signal declarations

    reg [31:0] counter;



    //TODO: Rst and stream out rdy signal propagation and synchronization logic among different MAC units

    always @(posedge clk) begin
        if (rst) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

    genvar i;
    generate
        for (i = 0; i < COLS; i = i + 1) begin : ctrl_gen
            localparam START_CYCLE = MULT_LAT + ACC_LAT - 1 + (COLS - 1 - i);
            assign rst_accumulator[i] = (counter >= START_CYCLE) && ((counter - START_CYCLE) % K == 0);
            assign stream_out_rdy[i] = (counter >= START_CYCLE) && ((counter - START_CYCLE) % K == 0);
        end
    endgenerate



endmodule
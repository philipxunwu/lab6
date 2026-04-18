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

    // Signal declarations
    reg [COLS-2:0] rst_delay;
    reg [COLS-2:0] stream_delay;

    // Rst and stream out rdy signal propagation and synchronization logic among different MAC units
    always @(posedge clk) begin
        if (rst) begin
            rst_delay <= 0;
            stream_delay <= 0;
        end else begin
            rst_delay <= {input_rst_accumulator, rst_delay[COLS-2:1]};
            stream_delay <= {input_stream_out_rdy, stream_delay[COLS-2:1]};
        end
    end

    assign rst_accumulator[0] = input_rst_accumulator;
    assign stream_out_rdy[0] = input_stream_out_rdy;
    generate
        for (genvar j = 1; j < COLS; j = j + 1) begin
            assign rst_accumulator[j] = rst_delay[j-1];
            assign stream_out_rdy[j] = stream_delay[j-1];
        end
    endgenerate

endmodule
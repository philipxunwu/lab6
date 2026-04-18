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
    reg [COLS-1:0] rst_shift;
    reg [COLS-1:0] stream_shift;

    // Rst and stream out rdy signal propagation and synchronization logic among different MAC units
    always @(posedge clk) begin
        if (rst) begin
            rst_shift <= 0;
            stream_shift <= 0;
        end else begin
            rst_shift <= {rst_shift[COLS-2:0], input_rst_accumulator};
            stream_shift <= {stream_shift[COLS-2:0], input_stream_out_rdy};
        end
    end

    assign rst_accumulator = rst_shift;
    assign stream_out_rdy = stream_shift;

endmodule
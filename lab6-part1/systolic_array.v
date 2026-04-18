module systolic_array #(
    parameter IN_WIDTH          = 8,
    parameter IN_FRAC           = 0,
    parameter OUT_WIDTH         = 8,
    parameter OUT_FRAC          = 0,
    parameter MULT_LAT          = 3,                 // Multiplication latency
    parameter ACC_LAT           = 1,                 // Addition latency (<=1, not support pipelined acc)
    parameter ROWS              = 4,                 // Row number of systolic array
    parameter K                 = 4,
    parameter COLS              = 4                  // Column number of systolic array
)(
    input                       clk,
    input                       rst_in,
    input                       rst_accumulator_rdy_in, // If 1, reset accumulator in array
    input                       stream_out_rdy_in_in,      // If 1, stream acc result out

    input [IN_WIDTH*ROWS-1:0]   row_data_in_in,         
    input [IN_WIDTH*COLS-1:0]   col_data_in_in,         
    output [OUT_WIDTH*ROWS-1:0] row_data_out
);
    //TODO: Signal declarations
    // register inputs // something todo with verilator timing issue
    reg       rst;
    reg       rst_accumulator_rdy;
    reg       stream_out_rdy;
    reg [IN_WIDTH*ROWS-1:0] row_data_in;
    reg [IN_WIDTH*COLS-1:0] col_data_in;

    always @(posedge clk) begin
        if (rst_in) begin
            rst <= 1;
            rst_accumulator_rdy <= 0;
            stream_out_rdy <= 0;
            row_data_in <= 0;
            col_data_in <= 0;
        end else begin
            rst <= rst_in;
            rst_accumulator_rdy <= rst_accumulator_rdy_in;
            stream_out_rdy <= stream_out_rdy_in_in;
            row_data_in <= row_data_in_in;
            col_data_in <= col_data_in_in;
        end
    end

    // Ctrl unit instantiation
    wire [COLS-1:0] rst_accumulator;
    wire [COLS-1:0] stream_out_rdy_ctrl;
    ctrl #(
        .IN_WIDTH(IN_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MULT_LAT(MULT_LAT),
        .ACC_LAT(ACC_LAT)
    ) ctrl_inst (
        .clk(clk),
        .rst(rst),
        .input_rst_accumulator(rst_accumulator_rdy),
        .input_stream_out_rdy(stream_out_rdy),
        .rst_accumulator(rst_accumulator),
        .stream_out_rdy(stream_out_rdy_ctrl)
    );

    // MAC units instantiation
    wire [OUT_WIDTH-1:0] psum [ROWS-1:0][COLS-1:0];
    wire [IN_WIDTH-1:0] row_pass [ROWS-1:0][COLS-1:0];
    wire [IN_WIDTH-1:0] col_pass [ROWS-1:0][COLS-1:0];
    wire [OUT_WIDTH-1:0] bypass_pass [ROWS-1:0][COLS-1:0];
    wire rst_acc_pass [ROWS-1:0][COLS-1:0];
    wire stream_rdy_pass [ROWS-1:0][COLS-1:0];

    generate
        for (genvar i = 0; i < ROWS; i = i + 1) begin
            for (genvar j = 0; j < COLS; j = j + 1) begin
                wire [IN_WIDTH-1:0] row_in = (j == 0) ? row_data_in[i*IN_WIDTH +: IN_WIDTH] : row_pass[i][j-1];
                wire [IN_WIDTH-1:0] col_in = (i == 0) ? col_data_in[j*IN_WIDTH +: IN_WIDTH] : col_pass[i-1][j];
                wire [OUT_WIDTH-1:0] bypass_in = ((i == 0) || (j == 0)) ? 0 : bypass_pass[i-1][j-1];
                wire rst_acc_in = (i == 0) ? rst_accumulator[j] : rst_acc_pass[i-1][j];
                wire stream_rdy_in = (i == 0) ? stream_out_rdy_ctrl[j] : stream_rdy_pass[i-1][j];

                mac #(
                    .IN_WIDTH(IN_WIDTH),
                    .IN_FRAC(IN_FRAC),
                    .OUT_WIDTH(OUT_WIDTH),
                    .OUT_FRAC(OUT_FRAC),
                    .MULT_LAT(MULT_LAT),
                    .ADD_LAT(ACC_LAT),
                    .K(K),
                    .ROWS(ROWS),
                    .COLS(COLS),
                    .COLS_IDX(j),
                    .ROWS_IDX(i)
                ) mac_inst (
                    .clk(clk),
                    .rst(rst),
                    .rst_accumulator_in(rst_acc_in),
                    .stream_out_rdy_in(stream_rdy_in),
                    .row_data_in(row_in),
                    .col_data_in(col_in),
                    .bypass_data_in(bypass_in),
                    .row_data_out(row_pass[i][j]),
                    .col_data_out(col_pass[i][j]),
                    .rst_accumulator_out(rst_acc_pass[i][j]),
                    .stream_out_rdy_out(stream_rdy_pass[i][j]),
                    .bypass_data_out(bypass_pass[i][j]),
                    .psum_out(psum[i][j])
                );
            end
        end
    endgenerate

    // Output assignment
    generate
        for (genvar i = 0; i < ROWS; i = i + 1) begin
            assign row_data_out[i*OUT_WIDTH +: OUT_WIDTH] = psum[i][COLS-1];
        end
    endgenerate
    

endmodule

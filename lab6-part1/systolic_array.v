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
    input                       stream_out_rdy_in_in,   // If 1, stream acc result out

    input  [IN_WIDTH*ROWS-1:0]  row_data_in_in,         
    input  [IN_WIDTH*COLS-1:0]  col_data_in_in,         
    output [OUT_WIDTH*ROWS-1:0] row_data_out
);

    // Register inputs to avoid Verilator timing races
    reg                       rst;
    reg                       rst_accumulator_rdy;
    reg                       stream_out_rdy;
    reg  [IN_WIDTH*ROWS-1:0]  row_data_in;
    reg  [IN_WIDTH*COLS-1:0]  col_data_in;

    always @(posedge clk) begin
        rst                 <= rst_in;
        rst_accumulator_rdy <= rst_accumulator_rdy_in;
        stream_out_rdy      <= stream_out_rdy_in_in;
        row_data_in         <= row_data_in_in;
        col_data_in         <= col_data_in_in;
    end

    // Ctrl unit instantiation
    wire [COLS-1:0] ctrl_rst_acc;
    wire [COLS-1:0] ctrl_stream_out;

    ctrl #(
        .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH),
        .ROWS(ROWS), .COLS(COLS),
        .MULT_LAT(MULT_LAT), .ACC_LAT(ACC_LAT)
    ) ctrl_inst (
        .clk(clk),
        .rst(rst),
        .input_rst_accumulator(rst_accumulator_rdy),
        .input_stream_out_rdy(stream_out_rdy),
        .rst_accumulator(ctrl_rst_acc),
        .stream_out_rdy(ctrl_stream_out)
    );

    // 2D Wires for connecting MAC boundaries
    wire [IN_WIDTH-1:0]  row_wire [ROWS-1:0][COLS:0];
    wire [IN_WIDTH-1:0]  col_wire [ROWS:0][COLS-1:0];
    wire                 rst_acc_wire [ROWS:0][COLS-1:0];
    wire                 stream_rdy_wire [ROWS:0][COLS-1:0];
    wire [OUT_WIDTH-1:0] psum_wire [ROWS-1:0][COLS:0];

    // MAC units instantiation
    genvar i, j;
    generate
        for (i = 0; i < ROWS; i = i + 1) begin : row_gen
            
            // Leftmost row inputs from top module
            assign row_wire[i][0] = row_data_in[i*IN_WIDTH +: IN_WIDTH];
            // Rightmost bypass inputs tied to 0
            assign psum_wire[i][COLS] = {OUT_WIDTH{1'b0}};
            // Leftmost outputs mapped to the top module output bus
            assign row_data_out[i*OUT_WIDTH +: OUT_WIDTH] = psum_wire[i][0];

            for (j = 0; j < COLS; j = j + 1) begin : col_gen
                
                // Topmost column inputs from top module / ctrl unit
                if (i == 0) begin
                    assign col_wire[0][j]        = col_data_in[j*IN_WIDTH +: IN_WIDTH];
                    assign rst_acc_wire[0][j]    = ctrl_rst_acc[j];
                    assign stream_rdy_wire[0][j] = ctrl_stream_out[j];
                end

                mac #(
                    .IN_WIDTH(IN_WIDTH), .IN_FRAC(IN_FRAC),
                    .OUT_WIDTH(OUT_WIDTH), .OUT_FRAC(OUT_FRAC),
                    .MULT_LAT(MULT_LAT), .ADD_LAT(ACC_LAT),
                    .K(K), .ROWS(ROWS), .COLS(COLS),
                    .COLS_IDX(j), .ROWS_IDX(i)
                ) pe (
                    .clk(clk),
                    .rst(rst),
                    
                    // Inputs from Left (Row) / Top (Col) / Right (Bypass)
                    .row_data_in(row_wire[i][j]),
                    .col_data_in(col_wire[i][j]),
                    .bypass_data_in(psum_wire[i][j+1]),
                    .rst_accumulator_in(rst_acc_wire[i][j]),
                    .stream_out_rdy_in(stream_rdy_wire[i][j]),
                    
                    // Outputs to Right (Row) / Bottom (Col) / Left (Psum)
                    .row_data_out(row_wire[i][j+1]),
                    .col_data_out(col_wire[i+1][j]),
                    .rst_accumulator_out(rst_acc_wire[i+1][j]),
                    .stream_out_rdy_out(stream_rdy_wire[i+1][j]),
                    .psum_out(psum_wire[i][j])
                );
            end
        end
    endgenerate

endmodule
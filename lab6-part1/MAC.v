module mac #(
    parameter IN_WIDTH = 8,
    parameter IN_FRAC = 0,
    parameter OUT_WIDTH = 8,
    parameter OUT_FRAC = 0,
    parameter MULT_LAT = 3,
    parameter ADD_LAT = 1,
    parameter K = 1,
    parameter ROWS = 1,
    parameter COLS = 1,
    parameter COLS_IDX = 1,
    parameter ROWS_IDX = 1
)(
    input                      clk,
    input                      rst,
    input                      rst_accumulator_in,
    input                      stream_out_rdy_in,
    input       [IN_WIDTH-1:0] row_data_in,
    input       [IN_WIDTH-1:0] col_data_in,
    input       [OUT_WIDTH-1:0] bypass_data_in, 
    output reg  [IN_WIDTH-1:0] row_data_out,
    output reg  [IN_WIDTH-1:0] col_data_out,
    output reg                 rst_accumulator_out,
    output reg                 stream_out_rdy_out,
    output reg [OUT_WIDTH-1:0] bypass_data_out,
    output reg [OUT_WIDTH-1:0] psum_out
);

    // Signal declarations
    wire mult_done;
    wire [OUT_WIDTH-1:0] mult_out;
    wire add_done;
    wire [OUT_WIDTH-1:0] add_out;
    reg [OUT_WIDTH-1:0] accumulator;

    // Multiplier instantiation
    multiplier #(
        .INPUT_A_WIDTH(IN_WIDTH),
        .INPUT_B_WIDTH(IN_WIDTH),
        .INPUT_A_FRAC(IN_FRAC),
        .INPUT_B_FRAC(IN_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH),
        .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(MULT_LAT)
    ) mult_inst (
        .clk(clk),
        .reset(rst),
        .en(1'b1),
        .stall(1'b0),
        .a_in(row_data_in),
        .b_in(col_data_in),
        .out(mult_out),
        .done(mult_done)
    );

    // Adder instantiation
    adder #(
        .INPUT_A_WIDTH(OUT_WIDTH),
        .INPUT_A_FRAC(OUT_FRAC),
        .INPUT_B_WIDTH(OUT_WIDTH),
        .INPUT_B_FRAC(OUT_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH),
        .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(ADD_LAT)
    ) add_inst (
        .clk(clk),
        .reset(rst),
        .en(mult_done),
        .stall(1'b0),
        .a_in(mult_out),
        .b_in(bypass_data_in),
        .out(add_out),
        .done(add_done)
    );

    // Signal propagation and synchronization
    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            psum_out <= 0;
            row_data_out <= 0;
            col_data_out <= 0;
            rst_accumulator_out <= 0;
            stream_out_rdy_out <= 0;
            bypass_data_out <= 0;
        end else begin
            if (rst_accumulator_in) begin
                accumulator <= 0;
            end else if (add_done) begin
                accumulator <= add_out;
            end
            if (stream_out_rdy_in) begin
                psum_out <= accumulator;
            end
            row_data_out <= row_data_in;
            col_data_out <= col_data_in;
            rst_accumulator_out <= rst_accumulator_in;
            stream_out_rdy_out <= stream_out_rdy_in;
            bypass_data_out <= accumulator;
        end
    end

endmodule

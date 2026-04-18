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
    output reg [OUT_WIDTH-1:0] psum_out
);

    wire [OUT_WIDTH-1:0] mult_out;
    wire [OUT_WIDTH-1:0] add_out;

    // Shift registers to delay control signals by MULT_LAT
    reg [15:0] rst_acc_delay;
    reg [15:0] stream_rdy_delay;

    always @(posedge clk) begin
        if (rst) begin
            rst_acc_delay       <= 16'b0;
            stream_rdy_delay    <= 16'b0;
            row_data_out        <= 0;
            col_data_out        <= 0;
            rst_accumulator_out <= 0;
            stream_out_rdy_out  <= 0;
        end else begin
            // Shift control signals
            rst_acc_delay       <= {rst_acc_delay[14:0], rst_accumulator_in};
            stream_rdy_delay    <= {stream_rdy_delay[14:0], stream_out_rdy_in};
            
            // Pass data down and right
            row_data_out        <= row_data_in;
            col_data_out        <= col_data_in;
            rst_accumulator_out <= rst_accumulator_in;
            stream_out_rdy_out  <= stream_out_rdy_in;
        end
    end

    // Tap the delay line at MULT_LAT to sync with the multiplier output
    wire delayed_rst    = (MULT_LAT > 0) ? rst_acc_delay[MULT_LAT] : rst_accumulator_in;
    wire delayed_stream = (MULT_LAT > 0) ? stream_rdy_delay[MULT_LAT] : stream_out_rdy_in;

    // Multiplier Instantiation
    multiplier #(
        .INPUT_A_WIDTH(IN_WIDTH), .INPUT_B_WIDTH(IN_WIDTH),
        .INPUT_A_FRAC(IN_FRAC), .INPUT_B_FRAC(IN_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH), .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(MULT_LAT)
    ) mult_inst (
        .clk(clk),
        .reset(rst),
        .en(1'b1),
        .stall(1'b0),
        .a_in(row_data_in),
        .b_in(col_data_in),
        .out(mult_out),
        .done()
    );

    // Adder Routing Logic:
    // If reset: Add 0 + 0 to reset accumulator.
    // If streaming: Add bypass_data_in + 0 to shift it to add_out next cycle.
    // If compute: Add mult_out + add_out (accumulate) OR mult_out + 0 (if reset).
    wire [OUT_WIDTH-1:0] adder_a = delayed_rst ? {OUT_WIDTH{1'b0}} : (delayed_stream ? bypass_data_in : mult_out);
    wire [OUT_WIDTH-1:0] adder_b = (delayed_stream || delayed_rst) ? {OUT_WIDTH{1'b0}} : add_out;

    // Adder Instantiation
    adder #(
        .INPUT_A_WIDTH(OUT_WIDTH), .INPUT_B_WIDTH(OUT_WIDTH),
        .INPUT_A_FRAC(OUT_FRAC), .INPUT_B_FRAC(OUT_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH), .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(ADD_LAT)
    ) add_inst (
        .clk(clk),
        .reset(rst),
        .en(1'b1),
        .stall(1'b0),
        .a_in(adder_a),
        .b_in(adder_b),
        .out(add_out),
        .done()
    );

    // Output the current internal register value directly so the left neighbor
    // can read it synchronously during the shift out.
    always @(*) begin
        psum_out = add_out;
    end

endmodule
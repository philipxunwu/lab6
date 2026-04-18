module mac #(
    parameter IN_WIDTH = 8,
    parameter IN_FRAC = 0,
    parameter OUT_WIDTH = 16,
    parameter OUT_FRAC = 0,
    parameter MULT_LAT = 1,
    parameter ADD_LAT = 1
)(
    input                          clk,
    input                          rst,
    input                          rst_accumulator_in,
    input                          stream_out_rdy_in,
    input        [IN_WIDTH-1:0]    row_data_in,
    input        [IN_WIDTH-1:0]    col_data_in,
    input        [OUT_WIDTH-1:0]   bypass_data_in, // From PE to the right
    output reg   [IN_WIDTH-1:0]    row_data_out,
    output reg   [IN_WIDTH-1:0]    col_data_out,
    output reg                     rst_accumulator_out,
    output reg                     stream_out_rdy_out,
    output reg   [OUT_WIDTH-1:0]   psum_out        // To PE to the left
);

    wire [OUT_WIDTH-1:0] mult_out;
    wire [OUT_WIDTH-1:0] adder_out;
    reg  [OUT_WIDTH-1:0] accumulator;

    // --- Systolic Control & Data Propagation ---
    always @(posedge clk) begin
        if (rst) begin
            row_data_out        <= 0;
            col_data_out        <= 0;
            rst_accumulator_out <= 0;
            stream_out_rdy_out  <= 0;
        end else begin
            row_data_out        <= row_data_in;
            col_data_out        <= col_data_in;
            rst_accumulator_out <= rst_accumulator_in;
            stream_out_rdy_out  <= stream_out_rdy_in;
        end
    end

    // --- Mandatory IP Instantiations ---
    multiplier #(
        .INPUT_A_WIDTH(IN_WIDTH), .INPUT_B_WIDTH(IN_WIDTH),
        .OUTPUT_WIDTH(OUT_WIDTH), .DELAY(MULT_LAT)
    ) mult_inst (
        .clk(clk), .reset(rst), .en(1'b1), .stall(1'b0),
        .a_in(row_data_in), .b_in(col_data_in),
        .out(mult_out)
    );

    adder #(
        .INPUT_A_WIDTH(OUT_WIDTH), .INPUT_B_WIDTH(OUT_WIDTH),
        .OUTPUT_WIDTH(OUT_WIDTH), .DELAY(ADD_LAT)
    ) addr_inst (
        .clk(clk), .reset(rst), .en(1'b1), .stall(1'b0),
        .a_in(mult_out), .b_in(accumulator),
        .out(adder_out)
    );

    // --- Accumulation & Streaming Logic ---
    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            psum_out    <= 0;
        end else begin
            // Accumulator updates
            if (rst_accumulator_in)
                accumulator <= mult_out; // Start new dot product
            else
                accumulator <= adder_out;

            // Output stationary shift-out
            // When stream_out_rdy_in is high, we push local result into the chain.
            // Otherwise, we pass the data from the right-hand neighbor.
            if (stream_out_rdy_in)
                psum_out <= accumulator;
            else
                psum_out <= bypass_data_in;
        end
    end
endmodule
// module mac #(
//     parameter IN_WIDTH = 8,
//     parameter IN_FRAC = 0,
//     parameter OUT_WIDTH = 8,
//     parameter OUT_FRAC = 0,
//     parameter MULT_LAT = 3,
//     parameter ADD_LAT = 1,
//     parameter K = 1,
//     parameter ROWS = 1,
//     parameter COLS = 1,
//     parameter COLS_IDX = 1,
//     parameter ROWS_IDX = 1
// )(
//     input                      clk,
//     input                      rst,
//     input                      rst_accumulator_in,
//     input                      stream_out_rdy_in,
//     input       [IN_WIDTH-1:0] row_data_in,
//     input       [IN_WIDTH-1:0] col_data_in,
//     input       [IN_WIDTH-1:0] bypass_data_in, 
//     output reg  [IN_WIDTH-1:0] row_data_out,
//     output reg  [IN_WIDTH-1:0] col_data_out,
//     output reg                 rst_accumulator_out,
//     output reg                 stream_out_rdy_out,
//     output reg [OUT_WIDTH-1:0] psum_out
// );


//     //TODO: Signal declarations

//     reg [OUT_WIDTH-1:0] accumulator; 
//     reg [IN_WIDTH-1:0] row_data_reg; 
//     reg [IN_WIDTH-1:0] col_data_reg; 
//     reg [IN_WIDTH-1:0] bypass_data_reg; 
//     reg stream_out_rdy_reg; 
//     reg rst_accumulator_reg; 

//     wire signed [OUT_WIDTH-1:0] mult_out;
//     wire mult_done;
//     wire signed [OUT_WIDTH-1:0] add_out;
//     wire add_done; 


//     //TODO: multiplier instantiation
//     multiplier #(
//         .INPUT_A_WIDTH(IN_WIDTH),
//         .INPUT_B_WIDTH(IN_WIDTH),
//         .INPUT_A_FRAC(IN_FRAC),
//         .INPUT_B_FRAC(IN_FRAC),
//         .OUTPUT_WIDTH(OUT_WIDTH),
//         .OUTPUT_FRAC(OUT_FRAC),
//         .DELAY(MULT_LAT)
//     ) mult_inst (
//         .clk(clk),
//         .reset(rst),
//         .en(1'b1),
//         .stall(1'b0),
//         .a_in(row_data_in),
//         .b_in(col_data_in),
//         .out(mult_out),
//         .done(mult_done)
//     );
//     //TODO: adder instantiation
//     adder #(
//         .INPUT_A_WIDTH(OUT_WIDTH),
//         .INPUT_B_WIDTH(OUT_WIDTH),
//         .INPUT_A_FRAC(OUT_FRAC),
//         .INPUT_B_FRAC(OUT_FRAC),
//         .OUTPUT_WIDTH(OUT_WIDTH),
//         .OUTPUT_FRAC(OUT_FRAC),
//         .DELAY(1)
//     ) add_inst (
//         .clk(clk),
//         .reset(rst),
//         .en(mult_done),
//         .stall(1'b0),
//         .a_in(mult_out),
//         .b_in(accumulator),
//         .out(add_out),
//         .done(add_done)
//     );


//     //TODO: signal propagation and synchronization
//     //Major approaches to look out for:
//     // 1. rst_accumulator and stream_out_rdy are major control signals that dictates the flow of the data and when to reset the accumulator between different matrix multiplications
//     // 2. An important part of the following design is to figure out how the data from multipliers and adders should be paired with the above two control signals
//     // 3. Mainly you need to know: should I pass the results of this very own MAC's accumulator to the next MAC's accumulator or should I pass the results of the previous MAC's accumulator to this MAC's accumulator and when to do so
//     // 4. Also, when should be the exact time point to reset the accumulator so my current results will not be cleared by mistake and the next matrix multiplication can start cleanly.

//     row_data_reg <= row_data_in; 
//     col_data_reg <= col_data_in; 
//     bypass_data_reg <= bypass_data_in; 

//     row_data_out <= row_data_reg; 
//     col_data_out <= col_data_reg;

//     rst_accumulator_out <= rst_accumulator_reg; 
//     stream_out_rdy_out <= stream_out_rdy_reg;

//     // take from adder for output
//     // take from multipler for accumulator 
//     if (stream_out_rdy_in & rst_accumulator_in) begin 
//         stream_out_rdy_reg <= stream_out_rdy_in; 
//         rst_accumulator_reg <= rst_accumulator_in; 
//         psum_out <= add_out
//         accumulator <= mult_out; 
//     end 
//     if (bypass_data_in) begin 
//         psum_out <= bypass_data_reg; 
//     end



// endmodule




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
    input       [IN_WIDTH-1:0] bypass_data_in, 
    output reg  [IN_WIDTH-1:0] row_data_out,
    output reg  [IN_WIDTH-1:0] col_data_out,
    output reg                 rst_accumulator_out,
    output reg                 stream_out_rdy_out,
    output reg [OUT_WIDTH-1:0] psum_out
);

    // Signal declarations
    reg [OUT_WIDTH-1:0] accumulator; 
    reg [IN_WIDTH-1:0]  row_data_reg; 
    reg [IN_WIDTH-1:0]  col_data_reg; 
    reg [IN_WIDTH-1:0]  bypass_data_reg; 
    reg                 stream_out_rdy_reg; 
    reg                 rst_accumulator_reg; 

    wire signed [OUT_WIDTH-1:0] mult_out;
    wire                        mult_done;
    wire signed [OUT_WIDTH-1:0] add_out;
    wire                        add_done; 

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
        .INPUT_B_WIDTH(OUT_WIDTH),
        .INPUT_A_FRAC(OUT_FRAC),
        .INPUT_B_FRAC(OUT_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH),
        .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(1)
    ) add_inst (
        .clk(clk),
        .reset(rst),
        .en(mult_done),
        .stall(1'b0),
        .a_in(mult_out),
        .b_in(accumulator),
        .out(add_out),
        .done(add_done)
    );

    // Signal propagation and synchronization
    always @(posedge clk) begin
        if (rst) begin
            row_data_reg        <= 0;
            col_data_reg        <= 0;
            bypass_data_reg     <= 0;
            row_data_out        <= 0;
            col_data_out        <= 0;
            rst_accumulator_reg <= 0;
            stream_out_rdy_reg  <= 0;
            rst_accumulator_out <= 0;
            stream_out_rdy_out  <= 0;
            psum_out            <= 0;
            accumulator         <= 0;
        end else begin
            // Internal register updates
            row_data_reg    <= row_data_in; 
            col_data_reg    <= col_data_in; 
            bypass_data_reg <= bypass_data_in; 

            // Propagation to outputs (systolic flow)
            row_data_out    <= row_data_reg; 
            col_data_out    <= col_data_reg;

            rst_accumulator_out <= rst_accumulator_reg; 
            stream_out_rdy_out  <= stream_out_rdy_reg;

            // Update accumulator based on computation flow
            if (add_done) begin
                if (rst_accumulator_in) begin
                    accumulator <= mult_out; // Start of new accumulation
                end else begin
                    accumulator <= add_out; // Continue accumulation
                end
            end

            // Conditional logic for streaming out and resetting
            if (stream_out_rdy_in & rst_accumulator_in) begin 
                stream_out_rdy_reg  <= stream_out_rdy_in; 
                rst_accumulator_reg <= rst_accumulator_in; 
                psum_out            <= add_out; 
                // accumulator         <= mult_out; 
            end 

            // Bypass logic (overwrites psum_out if active)
            if (bypass_data_in != 0) begin 
                psum_out <= bypass_data_reg; 
            end
        end
    end

endmodule
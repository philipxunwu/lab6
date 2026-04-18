// module systolic_array #(
//     parameter IN_WIDTH          = 8,
//     parameter IN_FRAC           = 0,
//     parameter OUT_WIDTH         = 8,
//     parameter OUT_FRAC          = 0,
//     parameter MULT_LAT          = 3,                 // Multiplication latency
//     parameter ACC_LAT           = 1,                 // Addition latency (<=1, not support pipelined acc)
//     parameter ROWS              = 4,                 // Row number of systolic array
//     parameter K                 = 4,
//     parameter COLS              = 4                  // Column number of systolic array
// )(
//     input                       clk,
//     input                       rst_in,
//     input                       rst_accumulator_rdy_in, // If 1, reset accumulator in array
//     input                       stream_out_rdy_in_in,      // If 1, stream acc result out

//     input [IN_WIDTH*ROWS-1:0]   row_data_in_in,         
//     input [IN_WIDTH*COLS-1:0]   col_data_in_in,         
//     output [OUT_WIDTH*ROWS-1:0] row_data_out
// );
//     //TODO: Signal declarations
//     // register inputs // something todo with verilator timing issue
//     reg       rst;
//     reg       rst_accumulator_rdy;
//     reg       stream_out_rdy;
//     reg [IN_WIDTH*ROWS-1:0] row_data_in;
//     reg [IN_WIDTH*COLS-1:0] col_data_in;

//     wire [OUT_WIDTH-1:0] psum [0:ROWS-1][0:COLS-1];
//     wire [IN_WIDTH-1:0] row_data [0:ROWS-1][0:COLS];
//     wire [IN_WIDTH-1:0] col_data [0:ROWS][0:COLS-1];
//     wire rst_acc [0:ROWS][0:COLS-1];
//     wire stream_rdy [0:ROWS][0:COLS-1];

//     always @(posedge clk) begin
//         rst <= rst_in;
//         rst_accumulator_rdy <= rst_accumulator_rdy_in;
//         stream_out_rdy <= stream_out_rdy_in_in;
//         row_data_in <= row_data_in_in;
//         col_data_in <= col_data_in_in;
//     end

//     generate
//         for (genvar r = 0; r < ROWS; r = r + 1) begin
//             assign row_data[r][0] = row_data_in[r*IN_WIDTH +: IN_WIDTH];
//         end
//         for (genvar c = 0; c < COLS; c = c + 1) begin
//             assign col_data[0][c] = col_data_in[c*IN_WIDTH +: IN_WIDTH];
//         end
//     endgenerate



//     //TODO: MAC units instantiation
//     // - Image you are drawing a spatial diagram of the MAC units; how should you connect the wires of them?
//     // - Use generate block to realize the spatial diagram (You are not required to use generate block though)

//     generate
//         for (genvar r = 0; r < ROWS; r = r + 1) begin : row_gen
//             for (genvar c = 0; c < COLS; c = c + 1) begin : col_gen
//                 mac #(
//                     .IN_WIDTH(IN_WIDTH),
//                     .IN_FRAC(IN_FRAC),
//                     .OUT_WIDTH(OUT_WIDTH),
//                     .OUT_FRAC(OUT_FRAC),
//                     .MULT_LAT(MULT_LAT),
//                     .ADD_LAT(ACC_LAT),
//                     .K(K),
//                     .ROWS(ROWS),
//                     .COLS(COLS),
//                     .COLS_IDX(c),
//                     .ROWS_IDX(r)
//                 ) mac_inst (
//                     .clk(clk),
//                     .rst(rst),
//                     .rst_accumulator_in(rst_acc[r][c]),
//                     .stream_out_rdy_in(stream_rdy[r][c]),
//                     .row_data_in(row_data[r][c]),
//                     .col_data_in(col_data[r][c]),
//                     .bypass_data_in(c == 0 ? {IN_WIDTH{1'b0}} : psum[r][c-1]),
//                     .row_data_out(row_data[r][c+1]),
//                     .col_data_out(col_data[r+1][c]),
//                     .rst_accumulator_out(rst_acc[r+1][c]),
//                     .stream_out_rdy_out(stream_rdy[r+1][c]),
//                     .psum_out(psum[r][c])
//                 );
//             end
//         end
//     endgenerate
    

//     //TODO: Ctrl unit instantiation
//     // generate rst accmulator and bypass enable control signals

//     ctrl #(
//         .IN_WIDTH(IN_WIDTH),
//         .OUT_WIDTH(OUT_WIDTH),
//         .ROWS(ROWS),
//         .COLS(COLS),
//         .MULT_LAT(MULT_LAT),
//         .ACC_LAT(ACC_LAT),
//         .K(K)
//     ) ctrl_inst (
//         .clk(clk),
//         .rst(rst),
//         .input_rst_accumulator(rst_accumulator_rdy),
//         .input_stream_out_rdy(stream_out_rdy),
//         .rst_accumulator(rst_acc[0]),
//         .stream_out_rdy(stream_rdy[0])
//     );

//     generate
//         for (genvar r = 0; r < ROWS; r = r + 1) begin
//             assign row_data_out[r*OUT_WIDTH +: OUT_WIDTH] = psum[r][0];
//         end
//     endgenerate

// endmodule


module systolic_array #(
    parameter IN_WIDTH          = 8,
    parameter IN_FRAC           = 0,
    parameter OUT_WIDTH         = 8,
    parameter OUT_FRAC          = 0,
    parameter MULT_LAT          = 3,                 // Multiplication latency
    parameter ACC_LAT           = 1,                 // Addition latency
    parameter ROWS              = 4,                 // Row number of systolic array
    parameter K                 = 4,
    parameter COLS              = 4                  // Column number of systolic array
)(
    input                        clk,
    input                        rst_in,
    input                        rst_accumulator_rdy_in, // If 1, reset accumulator
    input                        stream_out_rdy_in_in,   // If 1, stream result out

    input  [IN_WIDTH*ROWS-1:0]   row_data_in_in,         
    input  [IN_WIDTH*COLS-1:0]   col_data_in_in,         
    output [OUT_WIDTH*ROWS-1:0]  row_data_out
);

    // Internal registered signals
    reg rst;
    reg rst_accumulator_rdy;
    reg stream_out_rdy;
    reg [IN_WIDTH*ROWS-1:0] row_data_in;
    reg [IN_WIDTH*COLS-1:0] col_data_in;

    // Grid wire declarations (Unpacked arrays for 2D structure)
    wire [OUT_WIDTH-1:0] psum [0:ROWS-1][0:COLS-1];
    wire [IN_WIDTH-1:0]  row_data [0:ROWS-1][0:COLS];
    wire [IN_WIDTH-1:0]  col_data [0:ROWS][0:COLS-1];
    wire                 rst_acc [0:ROWS][0:COLS-1];
    wire                 stream_rdy [0:ROWS][0:COLS-1];

    // Bridge wires for CTRL unit interface (Packed vectors)
    wire [COLS-1:0] ctrl_rst_acc_out;
    wire [COLS-1:0] ctrl_stream_rdy_out;

    // Synchronous input registration
    always @(posedge clk) begin
        rst                 <= rst_in;
        rst_accumulator_rdy <= rst_accumulator_rdy_in;
        stream_out_rdy      <= stream_out_rdy_in_in;
        row_data_in         <= row_data_in_in;
        col_data_in         <= col_data_in_in;
    end

    // Feed external inputs into the array boundaries
    generate
        for (genvar r = 0; r < ROWS; r = r + 1) begin : row_input_assign
            assign row_data[r][0] = row_data_in[r*IN_WIDTH +: IN_WIDTH];
        end
        for (genvar c = 0; c < COLS; c = c + 1) begin : col_input_assign
            assign col_data[0][c] = col_data_in[c*IN_WIDTH +: IN_WIDTH];
        end
    endgenerate

    // CTRL unit instantiation
    ctrl #(
        .IN_WIDTH(IN_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MULT_LAT(MULT_LAT),
        .ACC_LAT(ACC_LAT),
        .K(K)
    ) ctrl_inst (
        .clk(clk),
        .rst(rst),
        .input_rst_accumulator(rst_accumulator_rdy),
        .input_stream_out_rdy(stream_out_rdy),
        .rst_accumulator(ctrl_rst_acc_out),   // Packed output
        .stream_out_rdy(ctrl_stream_rdy_out)   // Packed output
    );

    // Bridge the packed CTRL signals to the first row of the grid
    generate
        for (genvar c = 0; c < COLS; c = c + 1) begin : ctrl_to_grid
            assign rst_acc[0][c] = ctrl_rst_acc_out[c];
            assign stream_rdy[0][c] = ctrl_stream_rdy_out[c];
        end
    endgenerate

    // Spatial MAC units instantiation
    generate
        for (genvar r = 0; r < ROWS; r = r + 1) begin : row_gen
            for (genvar c = 0; c < COLS; c = c + 1) begin : col_gen
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
                    .COLS_IDX(c),
                    .ROWS_IDX(r)
                ) mac_inst (
                    .clk(clk),
                    .rst(rst),
                    .rst_accumulator_in(rst_acc[r][c]),
                    .stream_out_rdy_in(stream_rdy[r][c]),
                    .row_data_in(row_data[r][c]),
                    .col_data_in(col_data[r][c]),
                    
                    // Boundary check for Partial Sum bypass: 
                    // MACs in column 0 receive zeros; others receive from the neighbor to the left
                    .bypass_data_in(c == 0 ? {IN_WIDTH{1'b0}} : psum[r][c-1][IN_WIDTH-1:0]), 
                    
                    .row_data_out(row_data[r][c+1]),
                    .col_data_out(col_data[r+1][c]),
                    .rst_accumulator_out(rst_acc[r+1][c]),
                    .stream_out_rdy_out(stream_rdy[r+1][c]),
                    .psum_out(psum[r][c])
                );
            end
        end
    endgenerate

    // Map leftmost partial sums to the final output
    generate
        for (genvar r = 0; r < ROWS; r = r + 1) begin : output_assign
            assign row_data_out[r*OUT_WIDTH +: OUT_WIDTH] = psum[r][0];
        end
    endgenerate

endmodule
module systolic_array #(
    parameter IN_WIDTH  = 8,
    parameter OUT_WIDTH = 16,
    parameter ROWS      = 4, // M
    parameter COLS      = 4, // N
    parameter K         = 4, // Inner dimension
    parameter MULT_LAT  = 1,
    parameter ACC_LAT   = 1
)(
    input                       clk,
    input                       rst,
    input                       rst_accumulator_rdy_in,
    input                       stream_out_rdy_in_in,
    input  [IN_WIDTH*ROWS-1:0]  row_data_in_in,         
    input  [IN_WIDTH*COLS-1:0]  col_data_in_in,         
    output [OUT_WIDTH*ROWS-1:0] row_data_out
);

    // Interconnect wires
    wire [IN_WIDTH-1:0]  r_bus [0:ROWS-1][0:COLS];
    wire [IN_WIDTH-1:0]  c_bus [0:ROWS][0:COLS-1];
    wire [OUT_WIDTH-1:0] p_bus [0:ROWS-1][0:COLS];
    wire                 ctrl_rst [0:ROWS][0:COLS-1];
    wire                 ctrl_str [0:ROWS][0:COLS-1];

    wire [COLS-1:0] base_rst_line;
    wire [COLS-1:0] base_str_line;

    ctrl #(.COLS(COLS), .K(K), .MULT_LAT(MULT_LAT)) control_unit (
        .clk(clk), .rst(rst),
        .input_rst_accumulator(rst_accumulator_rdy_in),
        .input_stream_out_rdy(stream_out_rdy_in_in),
        .rst_accumulator(base_rst_line),
        .stream_out_rdy(base_str_line)
    );

    genvar r, c;
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : row_loop
            for (c = 0; c < COLS; c = c + 1) begin : col_loop
                
                // --- Boundary Assignments ---
                if (c == 0) assign r_bus[r][0] = row_data_in_in[(r+1)*IN_WIDTH-1 : r*IN_WIDTH];
                if (r == 0) begin
                    assign c_bus[0][c] = col_data_in_in[(c+1)*IN_WIDTH-1 : c*IN_WIDTH];
                    assign ctrl_rst[0][c] = base_rst_line[c];
                    assign ctrl_str[0][c] = base_str_line[c];
                end

                // --- PE Instantiation ---
                mac #(
                    .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH),
                    .MULT_LAT(MULT_LAT), .ADD_LAT(ACC_LAT)
                ) pe (
                    .clk(clk), .rst(rst),
                    .row_data_in(r_bus[r][c]),
                    .col_data_in(c_bus[r][c]),
                    .bypass_data_in( (c == COLS-1) ? {OUT_WIDTH{1'b0}} : p_bus[r][c+1] ),
                    .rst_accumulator_in(ctrl_rst[r][c]),
                    .stream_out_rdy_in(ctrl_str[r][c]),
                    .row_data_out(r_bus[r][c+1]),
                    .col_data_out(c_bus[r+1][c]),
                    .rst_accumulator_out(ctrl_rst[r+1][c]),
                    .stream_out_rdy_out(ctrl_str[r+1][c]),
                    .psum_out(p_bus[r][c])
                );

                // --- Final Result Extraction ---
                // The leftmost column (c=0) outputs the final result for each row
                if (c == 0) assign row_data_out[(r+1)*OUT_WIDTH-1 : r*OUT_WIDTH] = p_bus[r][0];
            end
        end
    endgenerate

endmodule
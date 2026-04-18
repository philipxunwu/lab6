module ctrl #(
    parameter COLS = 4,
    parameter K = 4,
    parameter MULT_LAT = 1
)(
    input clk,
    input rst,
    input input_rst_accumulator, // Pulse to start the first matrix
    input input_stream_out_rdy,  // Pulse to start streaming the first result
    output [COLS-1:0] rst_accumulator,
    output [COLS-1:0] stream_out_rdy
);

    // Periodic pulse generation for pipelined matrices
    reg [$clog2(K):0] k_count;
    reg active;
    wire tick = (k_count == K-1);

    always @(posedge clk) begin
        if (rst) begin
            k_count <= 0;
            active  <= 0;
        end else if (input_rst_accumulator) begin
            k_count <= 0;
            active  <= 1;
        end else if (active) begin
            k_count <= tick ? 0 : k_count + 1;
        end
    end

    // The base signal for all columns is skewed horizontally
    // Column J receives its pulse J cycles after Column 0
    wire base_rst = input_rst_accumulator || (active && tick);
    
    reg [COLS-1:0] rst_pipe;
    reg [COLS-1:0] stream_pipe;

    always @(posedge clk) begin
        if (rst) begin
            rst_pipe    <= 0;
            stream_pipe <= 0;
        end else begin
            // Right-shift pipe to create the horizontal wavefront
            rst_pipe    <= {rst_pipe[COLS-2:0], base_rst};
            stream_pipe <= {stream_pipe[COLS-2:0], input_stream_out_rdy};
        end
    end

    assign rst_accumulator = rst_pipe;
    assign stream_out_rdy  = stream_pipe;

endmodule
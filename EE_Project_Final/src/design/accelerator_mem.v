// Register file for the accelerator

module accelerator_mem #(
    parameter  MEM_DEPTH = 64,
    parameter DATA_WIDTH = 24,
    localparam ADDR_MEM_WIDTH = $clog2(MEM_DEPTH)  // Number of bits required to address the MEMORY
) (
    input wire clk,
    input wire  [ADDR_MEM_WIDTH-1:0] addr_a,
    input wire  [ADDR_MEM_WIDTH-1:0] addr_b,

    // Memory bank 0, for real parts
    input wire  [2:0] wen_b0,
    input wire  [DATA_WIDTH-1:0] wdata_b0,
    output wire [DATA_WIDTH-1:0] rdata_b0_a,
    output wire [DATA_WIDTH-1:0] rdata_b0_b,

    // Memory bank 1, for complex parts
    input wire  [2:0] wen_b1,
    input wire  [DATA_WIDTH-1:0] wdata_b1,
    output wire [DATA_WIDTH-1:0] rdata_b1_a,
    output wire [DATA_WIDTH-1:0] rdata_b1_b
);

    // Memory bank 0， for real parts
    reg [DATA_WIDTH-1:0] mem_b0 [0:MEM_DEPTH-1];

    assign rdata_b0_a = mem_b0[addr_a];
    assign rdata_b0_b = mem_b0[addr_b];

    always @(posedge clk) begin
        if (wen_b0[0]) begin
            mem_b0[addr_a][ 7: 0] <= wdata_b0[ 7: 0];
        end
        if (wen_b0[1]) begin
            mem_b0[addr_a][15: 8] <= wdata_b0[15: 8];
        end
        if (wen_b0[2]) begin
            mem_b0[addr_a][DATA_WIDTH-1:16] <= wdata_b0[DATA_WIDTH-1:16];
        end
        /*if (wen_b0[3]) begin
            mem_b0[addr_a][DATA_WIDTH:24] <= wdata_b0[DATA_WIDTH:24];
        end*/ 
    end


    // Memory bank 1, for complex parts
    reg [DATA_WIDTH-1:0] mem_b1 [0:MEM_DEPTH-1];

    assign rdata_b1_a = mem_b1[addr_a];
    assign rdata_b1_b = mem_b1[addr_b];

    always @(posedge clk) begin
        if (wen_b1[0]) begin
            mem_b1[addr_a][ 7: 0] <= wdata_b1[ 7: 0];
        end
        if (wen_b1[1]) begin
            mem_b1[addr_a][15: 8] <= wdata_b1[15: 8];
        end
        if (wen_b1[2]) begin
            mem_b1[addr_a][DATA_WIDTH-1:16] <= wdata_b1[DATA_WIDTH-1:16];
        end
        /*if (wen_b1[3]) begin
            mem_b1[addr_a][DATA_WIDTH:24] <= wdata_b1[DATA_WIDTH:24];
        end*/ 
    end
endmodule
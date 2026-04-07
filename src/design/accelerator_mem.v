module accelerator_mem #(
    parameter  MEM_DEPTH = 64,
    localparam ADDR_MEM_WIDTH = $clog2(MEM_DEPTH) 
) (
    input wire clk,
    input wire [ADDR_MEM_WIDTH-1:0] addr,

    // Memory bank 0, for real parts
    input wire [3:0] wen_b0,
    input wire [31:0] wdata_b0,
    output wire[31:0] rdata_b0,

    // Memory bank 1, for complex parts
    input wire [3:0] wen_b1,
    input wire [31:0] wdata_b1,
    output wire[31:0] rdata_b1
);

    reg [31:0] mem_b0 [0:MEM_DEPTH-1];

    assign rdata_b0 = mem_b0[addr];

    always @(posedge clk) begin
        if (wen_b0[0]) mem_b0[addr][ 7: 0] <= wdata_b0[ 7: 0];
        if (wen_b0[1]) mem_b0[addr][15: 8] <= wdata_b0[15: 8];
        if (wen_b0[2]) mem_b0[addr][23:16] <= wdata_b0[23:16];
        if (wen_b0[3]) mem_b0[addr][31:24] <= wdata_b0[31:24];
    end

    reg [31:0] mem_b1 [0:MEM_DEPTH-1];

    assign rdata_b1 = mem_b1[addr];

    always @(posedge clk) begin
        if (wen_b1[0]) mem_b1[addr][ 7: 0] <= wdata_b1[ 7: 0];
        if (wen_b1[1]) mem_b1[addr][15: 8] <= wdata_b1[15: 8];
        if (wen_b1[2]) mem_b1[addr][23:16] <= wdata_b1[23:16];
        if (wen_b1[3]) mem_b1[addr][31:24] <= wdata_b1[31:24];
    end
endmodule

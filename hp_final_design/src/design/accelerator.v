module accelerator (
    input  wire        clk,
    input  wire        resetn,
    input  wire        iomem_valid,
    output wire        iomem_ready,
    input  wire [ 3:0] iomem_wstrb,
    input  wire [31:0] iomem_addr,
    input  wire [31:0] iomem_wdata,
    output wire [31:0] iomem_rdata
);
  localparam NUM_REGS = 4;  
  localparam NUM_REGS_WIDTH = $clog2(NUM_REGS);  
  localparam MEM_DEPTH = 64;
  localparam ADDR_WIDTH = $clog2(MEM_DEPTH);  
  localparam LOG_MAX_N = 32;  
  localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N);  
  integer i;

  wire reset_accel;
  wire enable_accel;
  wire finished_accel;

  wire [LOG_MAX_N-1:0] num_data;
  wire [LOG_MAX_FFT_STAGES-1:0] num_fft_stages;

  wire [ADDR_WIDTH-1:0] mem_addr;

  wire [31:0] mem_rdata_b0;
  wire [31:0] mem_wdata_b0;
  wire [3:0] mem_wstrb_b0;

  wire [31:0] mem_rdata_b1;
  wire [31:0] mem_wdata_b1;
  wire [3:0] mem_wstrb_b1;

  wire [3:0] accel_mem_wstrb;
  wire [31:0] accel_mem_addr;
  wire [31:0] accel_mem_wdata_re;
  wire [31:0] accel_mem_rdata_re;
  wire [31:0] accel_mem_wdata_im;
  wire [31:0] accel_mem_rdata_im;

  wire iomem_access_accelerator;  
  wire iomem_access_conf;  
  wire iomem_access_mem;  
  reg iomem_conf_ready;
  reg iomem_mem_ready;
  reg [31:0] iomem_conf_rdata;

  reg [31:0] iomem_accel[NUM_REGS-1:0];  
  wire [NUM_REGS_WIDTH-1:0] iomem_accel_addr;  

  wire [ADDR_WIDTH:0] pio_mem_addr;
  wire [31:0] pio_mem_rdata;
  wire pio_mem_bank_sel;
  wire [ADDR_WIDTH-1:0] pio_mem_bank_addr;

  accelerator_mem #(
    .MEM_DEPTH    (MEM_DEPTH)
  ) mem (
    .clk        (clk),                      
    .addr       (mem_addr),                 
    .wen_b0     (mem_wstrb_b0),             
    .wdata_b0   (mem_wdata_b0),             
    .rdata_b0   (mem_rdata_b0),             
    .wen_b1     (mem_wstrb_b1),             
    .wdata_b1   (mem_wdata_b1),             
    .rdata_b1   (mem_rdata_b1)              
  );

  accelerator_fft #(
      .LOG_MAX_N (LOG_MAX_N),
      .MEM_WIDTH (32),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) fft (
      .clk                   (clk),
      .resetn                (resetn),
      .reset_accel           (reset_accel),
      .enable_accel          (enable_accel),
      .num_data              (num_data),
      .num_fft_stages        (num_fft_stages),

      .accel_mem_wstrb       (accel_mem_wstrb),
      .accel_mem_addr        (accel_mem_addr),
      .accel_mem_rdata_re    (accel_mem_rdata_re),
      .accel_mem_wdata_re    (accel_mem_wdata_re),
      .accel_mem_rdata_im    (accel_mem_rdata_im),
      .accel_mem_wdata_im    (accel_mem_wdata_im),

      .fft_finished(finished_accel)
  );

  assign accel_mem_rdata_re = mem_rdata_b0;
  assign accel_mem_rdata_im = mem_rdata_b1;

  assign reset_accel = iomem_accel[0][0];
  assign enable_accel = iomem_accel[0][1];
  assign num_data = iomem_accel[1][LOG_MAX_N-1:0];
  assign num_fft_stages = iomem_accel[2][LOG_MAX_FFT_STAGES-1:0];

  assign iomem_access_accelerator = iomem_valid && iomem_addr[31:24] == 8'h03;
  assign iomem_access_conf = iomem_access_accelerator && (iomem_addr[23:0] >> 2) < NUM_REGS;
  assign iomem_access_mem = iomem_access_accelerator && (iomem_addr[23:0] >> 2) >= NUM_REGS;

  assign iomem_accel_addr = iomem_addr >> 2;

  assign iomem_ready = iomem_access_conf ? iomem_conf_ready : (iomem_access_mem ? iomem_mem_ready : 1'b0);
  assign iomem_rdata = iomem_access_conf ? iomem_conf_rdata : (iomem_access_mem ? pio_mem_rdata : 32'b0);

  assign pio_mem_addr = iomem_addr[23:2] - NUM_REGS; 
  assign pio_mem_bank_sel = pio_mem_addr[0];
  assign pio_mem_bank_addr = pio_mem_addr[ADDR_WIDTH:1];
  
  assign mem_addr = iomem_access_mem ? pio_mem_bank_addr : accel_mem_addr;

  assign mem_wstrb_b0 = iomem_access_mem ? (iomem_wstrb & {4{~pio_mem_bank_sel}}) : accel_mem_wstrb;
  assign mem_wdata_b0 = iomem_access_mem ? iomem_wdata : accel_mem_wdata_re;
  
  assign mem_wstrb_b1 = iomem_access_mem ? (iomem_wstrb & {4{pio_mem_bank_sel}}) : accel_mem_wstrb;
  assign mem_wdata_b1 = iomem_access_mem ? iomem_wdata : accel_mem_wdata_im;
  
  assign pio_mem_rdata = pio_mem_bank_sel ? mem_rdata_b1 : mem_rdata_b0;

  always @(posedge clk) begin
    if (!resetn) begin
      for (i = 0; i < NUM_REGS; i = i + 1) begin
        iomem_accel[i] <= 0;
      end
      iomem_conf_ready <= 0;
      iomem_mem_ready  <= 0;
    end 
    else begin
      iomem_accel[0][2] <= finished_accel;  

      if (iomem_access_conf && !iomem_conf_ready) begin
        iomem_conf_ready <= 1;
        iomem_conf_rdata <= iomem_accel[iomem_accel_addr];
        if (iomem_wstrb[0]) begin
          iomem_accel[iomem_accel_addr][7:0] <= iomem_wdata[7:0];
        end
        if (iomem_wstrb[1]) begin
          iomem_accel[iomem_accel_addr][15:8] <= iomem_wdata[15:8];
        end
        if (iomem_wstrb[2]) begin
          iomem_accel[iomem_accel_addr][23:16] <= iomem_wdata[23:16];
        end
        if (iomem_wstrb[3]) begin
          iomem_accel[iomem_accel_addr][31:24] <= iomem_wdata[31:24];
        end
      end 
      else begin
        iomem_conf_ready <= 0;
      end

      if (iomem_access_mem && !iomem_mem_ready) begin
        iomem_mem_ready <= 1'b1;
      end 
      else begin
        iomem_mem_ready <= 1'b0;
      end
    end
  end
endmodule

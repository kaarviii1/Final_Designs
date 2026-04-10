
/*##########################################################################
###
### Dummy accelerator module
###    
###     This is an accelerator module that implement the iterative (in-place) Cooley-Tukey FFT algorithm using a Moore FSM.
###
###     TU Delft ET4351
###     April 2023, C.Gao, C. Frenkel: 
###                - Baseline project for count from zero to the value of the input data.
###                - It is used to demonstrate the use of the accelerator interface.
###     April 2024, N.Chauvaux: 
###                - Sorting accelerator + memory interface
###     December 2024, Ang Li, Yizhuo Wu: 
###                - Pathfinding accelerator
###     January 2026, N.Chauvaux and Douwe den Blanken:
###                - FFT accelerator
###
##########################################################################*/

/* Accelerator Memory Map
    // CONFIGURATION FILE
	iomem_accel[0] | 0x0300_0000: 32-bit Config & Status Register (CSR)
        --Bit [31:3] <xxxxxx>  : Undefined. You can use these bits for your own purposes.
        --Bit 2      <Status>  : Done Flag (FFT finished)           | 0 = Not finished, 1 = Finished
        --Bit 1      <Config>  : Enable Accelerator (Active High)   | 0 = Disable, 1 = Enable
        --Bit 0      <Config>  : Reset Accelerator  (Active High)   | 0 = Assert,  1 = Release
    iomem_accel[1] | 0x300_0004: 32-bit Number data
    iomem_accel[2] | 0x300_0008: 32-bit General Purpose Input/Output (GPIO)
    iomem_accel[3] | 0x300_000C: 32-bit General Purpose Input/Output (GPIO)

    // MEMORY FILE
    MEM[0] | 0x0300_0010: 32-bit word
    MEM[1] | 0x0300_0014: 32-bit word
    ...
    ...
    ...
    ...
    MEM[31] | 0x0300_08C: 32-bit word
*/

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
  /*----------------------------------------------------------------------------------------
        SIGNALS DECLARATION
    ----------------------------------------------------------------------------------------*/
  /*
     * Declare Local Parameters
     */
  // Accelerator configuration registers
  localparam NUM_REGS = 4;  // Number of registers in the accelerator
  localparam NUM_REGS_WIDTH = $clog2(NUM_REGS);  // Number of bits required to address the registers
  // Accelerator internal memory
  // localparam MEM_DEPTH = 128;
  localparam DATA_WIDTH = 24; 
  localparam MEM_DEPTH = 64;
  localparam ADDR_WIDTH = $clog2(MEM_DEPTH);  // Number of bits required to address the MEMORY
  // Application specifications
  localparam LOG_MAX_N = 32;  // Maximum number of input samples is 2^32
  localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N);  // Maximum number of stage in the FFT
  integer i;

  /*
     * Declare internal signals
     */
  // Define accelerator execution control signals
  wire reset_accel;
  wire enable_accel;
  wire finished_accel;


  // Define FFT variables
  wire [LOG_MAX_N-1:0] num_data;
  wire [LOG_MAX_FFT_STAGES-1:0] num_fft_stages;
  wire [ADDR_WIDTH-1:0] num_twiddles;


  /// Define signals for the accelerator MEMORY
  wire [ADDR_WIDTH-1:0] mem_addr_a;
  wire [ADDR_WIDTH-1:0] mem_addr_b;

  wire [DATA_WIDTH-1:0] mem_rdata_b0_a;
  wire [DATA_WIDTH-1:0] mem_rdata_b0_b;
  wire [DATA_WIDTH-1:0] mem_wdata_b0;
  wire [2:0] mem_wstrb_b0;

  wire [DATA_WIDTH-1:0] mem_rdata_b1_a;
  wire [DATA_WIDTH-1:0] mem_rdata_b1_b;
  wire [DATA_WIDTH-1:0] mem_wdata_b1;
  wire [2:0] mem_wstrb_b1;


  // Define access signal on the accelerator MEMORY coming from the accelerator itself.
  wire [2:0] accel_mem_wstrb;
  wire [32-1:0] accel_mem_addr_a;
  wire [32-1:0] accel_mem_addr_b;
  // ccelerator memory for imaginary parts
  wire [DATA_WIDTH-1:0] accel_mem_wdata_re;
  wire [DATA_WIDTH-1:0] accel_mem_wdata_im;
  wire [DATA_WIDTH-1:0] accel_mem_rdata_re_a;
  wire [DATA_WIDTH-1:0] accel_mem_rdata_re_b;
  // Accelerator memory for imaginary parts
  wire [DATA_WIDTH-1:0] accel_mem_rdata_im_a;
  wire [DATA_WIDTH-1:0] accel_mem_rdata_im_b;



  // Define MEMORY/CONF access signal coming from the IOMEM(e.g. PICORV32)
  wire iomem_access_accelerator;  // Whether the PICO tries to access the accelerator
  wire iomem_access_conf;  // Whether the PICO tries to access the configuration registers
  wire iomem_access_mem;  // Whether the PICO tries to access the accelerator memory
  reg iomem_conf_ready;
  reg iomem_mem_ready;
  reg [32-1:0] iomem_conf_rdata;


  // Define the configuration register array
  reg [32-1:0] iomem_accel[NUM_REGS-1:0];  // Accelerator Registers
  wire [NUM_REGS_WIDTH-1:0] iomem_accel_addr;  // Accelerator Register Address


  // To create an illusion for the PicoSoC to let it believe that the accel_mem is still the same
  wire [ADDR_WIDTH:0] pio_mem_addr;
  wire [31:0] pio_mem_rdata;
  wire pio_mem_bank_sel;
  wire [ADDR_WIDTH-1:0] pio_mem_bank_addr;
  wire [DATA_WIDTH-1:0] pio_mem_rdata_quant;
  wire [DATA_WIDTH-1:0] pio_wdata_quantized;
  wire [2:0] pio_wstrb_quantized;

  /*----------------------------------------------------------------------------------------
        MEMORY AND ACCELERATOR
    ----------------------------------------------------------------------------------------*/
  // Instantiate the MEMORY of the accelerator
  accelerator_mem #(
    .MEM_DEPTH    (MEM_DEPTH)
  ) mem (
    .clk        (clk),                      // input
    .addr_a     (mem_addr_a),
    .addr_b     (mem_addr_b),
    // Memory bank 0
    .wen_b0     (mem_wstrb_b0),             // input
    .wdata_b0   (mem_wdata_b0),             // input
    .rdata_b0_a (mem_rdata_b0_a),           // output
    .rdata_b0_b (mem_rdata_b0_b),           // output
    // Memory bank 1
    .wen_b1     (mem_wstrb_b1),             // input
    .wdata_b1   (mem_wdata_b1),             // input
    .rdata_b1_a (mem_rdata_b1_a),           // output  
    .rdata_b1_b (mem_rdata_b1_b)           // output
  );

  // Instantiate the FFT accelerator
  accelerator_fft #(
      .LOG_MAX_N (LOG_MAX_N),
      .DATA_WIDTH (DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH), 
      .MEM_WIDTH (32)
  ) fft (
      .clk                   (clk),
      .resetn                (resetn),

      .reset_accel           (reset_accel),
      .enable_accel          (enable_accel),

      .num_data              (num_data),
      .num_fft_stages        (num_fft_stages),
      .num_twiddles          (num_twiddles),

      .accel_mem_wstrb       (accel_mem_wstrb),
      .accel_mem_addr_a      (accel_mem_addr_a),
      .accel_mem_addr_b      (accel_mem_addr_b),
      .accel_mem_wdata_re    (accel_mem_wdata_re),
      .accel_mem_wdata_im    (accel_mem_wdata_im),
      .accel_mem_rdata_re_a  (mem_rdata_b0_a),
      .accel_mem_rdata_im_a  (mem_rdata_b1_a),
      .accel_mem_rdata_re_b  (mem_rdata_b0_b),
      .accel_mem_rdata_im_b  (mem_rdata_b1_b),

      .fft_finished(finished_accel)
  );


  /*----------------------------------------------------------------------------------------
        INTERFACE LOGIC
    ----------------------------------------------------------------------------------------*/
  assign pio_wdata_quantized = iomem_wdata[DATA_WIDTH-1:0]; 
  assign pio_wstrb_quantized = iomem_wstrb[2:0]; 
  // Read paramemeters for the FFT algorithm
  assign reset_accel = iomem_accel[0][0];
  assign enable_accel = iomem_accel[0][1];
  assign num_data = iomem_accel[1][LOG_MAX_N-1:0];
  assign num_fft_stages = iomem_accel[2][LOG_MAX_FFT_STAGES-1:0];
  assign num_twiddles = iomem_accel[3][ADDR_WIDTH-1:0];

  assign iomem_access_accelerator = iomem_valid && iomem_addr[31:24] == 8'h03;
  assign iomem_access_conf = iomem_access_accelerator && (iomem_addr[23:0] >> 2) < NUM_REGS;
  assign iomem_access_mem = iomem_access_accelerator && (iomem_addr[23:0] >> 2) >= NUM_REGS;

  assign iomem_accel_addr = iomem_addr >> 2;

  // Select MEMORY or CONFIGURATION for the IOMEM interface
  assign iomem_ready = iomem_access_conf ? iomem_conf_ready : (iomem_access_mem ? iomem_mem_ready : 1'b0);
  assign iomem_rdata = iomem_access_conf ? iomem_conf_rdata : (iomem_access_mem ? pio_mem_rdata : 32'b0);

  assign pio_mem_addr = iomem_addr[23:2] - NUM_REGS; // Subtract NUM_REGS to skip the accelerator configuration registers
  assign pio_mem_bank_sel = pio_mem_addr[0];
  assign pio_mem_bank_addr = pio_mem_addr[ADDR_WIDTH:1];
  // assign mem_addr = iomem_access_mem ? {10'b0, iomem_addr[23:2] - NUM_REGS} : accel_mem_addr;
  // assign mem_addr = iomem_access_mem ? pio_mem_bank_addr : accel_mem_addr;
  assign mem_addr_a = iomem_access_mem ? pio_mem_bank_addr : accel_mem_addr_a;
  assign mem_addr_b = iomem_access_mem ? {ADDR_WIDTH{1'b0}} : accel_mem_addr_b;

  // Select IOMEM or ACCELERATOR to access the MEMORY for write operation
  // assign mem_wdata = iomem_access_mem ? iomem_wdata : accel_mem_wdata;
  // assign mem_wstrb = iomem_access_mem ? iomem_wstrb : accel_mem_wstrb;
  assign mem_wstrb_b0 = iomem_access_mem ? (pio_wstrb_quantized & {3{~pio_mem_bank_sel}}) : accel_mem_wstrb;
  assign mem_wdata_b0 = iomem_access_mem ? pio_wdata_quantized : accel_mem_wdata_re;
  
  assign mem_wstrb_b1 = iomem_access_mem ? (pio_wstrb_quantized & {3{pio_mem_bank_sel}}) : accel_mem_wstrb;
  assign mem_wdata_b1 = iomem_access_mem ? pio_wdata_quantized : accel_mem_wdata_im;
  
  assign pio_mem_rdata_quant = pio_mem_bank_sel ? mem_rdata_b1_a : mem_rdata_b0_a;
  assign pio_mem_rdata = {{(32-DATA_WIDTH){pio_mem_rdata_quant[DATA_WIDTH-1]}}, pio_mem_rdata_quant};

  // Manage the configuration register accesses.
  always @(posedge clk) begin
    if (!resetn) begin
      for (i = 0; i < NUM_REGS; i = i + 1) begin
        iomem_accel[i] <= 0;
      end

      iomem_conf_ready <= 0;

      iomem_mem_ready  <= 0;
    end 
    else begin
      iomem_accel[0][2] <= finished_accel;  // Output Finish Flag

      /*
       * Configuration register access control
       */
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

      /*
      * Accelerator memory access control
      */
      if (iomem_access_mem && !iomem_mem_ready) begin
        iomem_mem_ready <= 1'b1;
      end 
      else begin
        iomem_mem_ready <= 1'b0;
      end
    end
  end
endmodule
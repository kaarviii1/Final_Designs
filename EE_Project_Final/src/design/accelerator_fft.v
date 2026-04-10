module accelerator_fft #(
    parameter integer LOG_MAX_N = 32,                // Number of bits to represent the maximum number of input samples
    parameter integer MEM_WIDTH = 32,  // Width of memory data
    parameter integer ADDR_WIDTH = 32,  // Width of memory address
    parameter integer DATA_WIDTH = 24,
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)  // Maximum number of stage in the FFT
) (
    input wire clk,
    input wire resetn,

    // Control input
    input wire reset_accel,
    input wire enable_accel,

    // Data input
    input wire [LOG_MAX_N-1:0] num_data,  // number_data is N in the algorithm
    input wire [LOG_MAX_FFT_STAGES-1:0] num_fft_stages,          // Number of FFT stages required for the number of data provided
    input wire [ADDR_WIDTH-1:0] num_twiddles,

    // Memory inputs/outputs
    output reg [3-1:0] accel_mem_wstrb,
    output reg [32-1:0] accel_mem_addr_a,
    output reg [32-1:0] accel_mem_addr_b,
    input wire [DATA_WIDTH-1:0] accel_mem_rdata_re_a,
    input wire [DATA_WIDTH-1:0] accel_mem_rdata_re_b,
    input wire [DATA_WIDTH-1:0] accel_mem_rdata_im_a,
    input wire [DATA_WIDTH-1:0] accel_mem_rdata_im_b,
    output reg [DATA_WIDTH-1:0] accel_mem_wdata_re,
    output reg [DATA_WIDTH-1:0] accel_mem_wdata_im,

    // Data output
    output reg fft_finished
);

  localparam INIT = 3'b000;
  localparam BUTTERFLY_READ = 3'b001;
  localparam BUTTERFLY_COMPUTE = 3'b011;
  localparam BUTTERFLY_WRITE_E_AND_PREFETCH_W = 3'b111;
  localparam BUTTERFLY_WRITE_O = 3'b101;
  localparam FINISH = 3'b100;


  reg [2:0] current_state;
  reg [2:0] next_state;

  reg [LOG_MAX_N-1:0] m;
  reg [LOG_MAX_FFT_STAGES-1:0] stage;
  reg [LOG_MAX_N-1:0] base;
  reg [LOG_MAX_N-2:0] k;
  reg [LOG_MAX_N-2:0] half;
  reg [ADDR_WIDTH-1:0] twiddle_prefetch_addr;

  reg signed [DATA_WIDTH-1:0] w_re;
  reg signed [DATA_WIDTH-1:0] w_im;
  reg signed [DATA_WIDTH-1:0] u_re;
  reg signed [DATA_WIDTH-1:0] u_im;
  reg signed [DATA_WIDTH-1:0] v_re;
  reg signed [DATA_WIDTH-1:0] v_im;
  reg signed [DATA_WIDTH-1:0] e_re;
  reg signed [DATA_WIDTH-1:0] e_im;
  reg signed [DATA_WIDTH-1:0] o_re;
  reg signed [DATA_WIDTH-1:0] o_im;
  
  wire signed [DATA_WIDTH-1:0] iso_v_re;
  wire signed [DATA_WIDTH-1:0] iso_v_im;
  wire signed [DATA_WIDTH-1:0] iso_w_re;
  wire signed [DATA_WIDTH-1:0] iso_w_im;

  wire [LOG_MAX_FFT_STAGES-1:0] next_stage;
  wire [LOG_MAX_N-1:0] next_base;
  wire [LOG_MAX_N-2:0] next_k;
  wire [ADDR_WIDTH-1:0] input_data_base_addr;
  wire [ADDR_WIDTH-1:0] mem_index_base_k;
  wire [ADDR_WIDTH-1:0] mem_index_base_k_plus_half;
  reg signed [DATA_WIDTH-1:0] t_re;
  reg signed [DATA_WIDTH-1:0] t_im;
  reg signed [2*DATA_WIDTH-1:0] mult_re;
  reg signed [2*DATA_WIDTH-1:0] mult_im;

  wire trivial_state;

  localparam SCALE = 12;

  always @(posedge clk) begin
    if (!resetn || reset_accel) begin
      current_state <= INIT;
    end
    else begin
      current_state <= next_state;
    end
  end

  assign butterfly_loop_finished = (next_k == half);
  assign base_loop_finished = (next_base == num_data);
  //assign stage_loop_finished = (stage == num_fft_stages); {Could lead to computation problems}
  assign stage_loop_finished = (next_stage > num_fft_stages);
  assign next_k = k + 1;
  assign next_base = base + m;
  assign next_stage = stage + 1;
  assign trivial_state = (m <= 4);
  
  assign iso_v_re = (current_state == BUTTERFLY_COMPUTE) ? v_re : '0;
  assign iso_v_im = (current_state == BUTTERFLY_COMPUTE) ? v_im : '0;
  assign iso_w_re = (current_state == BUTTERFLY_COMPUTE) ? w_re : '0;
  assign iso_w_im = (current_state == BUTTERFLY_COMPUTE) ? w_im : '0;

  always @(*) begin
    case (current_state)
      INIT: begin
        if (enable_accel) begin
          if (num_data[LOG_MAX_N-1:1] == 0) begin
            next_state = FINISH; // If number_data < 2, finish FFT as the input does not change
          end
          else begin
            next_state = BUTTERFLY_READ;
          end
        end
        else begin
          next_state = INIT;
        end
      end


      BUTTERFLY_READ: begin
        next_state = BUTTERFLY_COMPUTE;
      end

      BUTTERFLY_COMPUTE: begin
        next_state = BUTTERFLY_WRITE_E_AND_PREFETCH_W;
      end

      BUTTERFLY_WRITE_E_AND_PREFETCH_W: begin
        next_state = BUTTERFLY_WRITE_O;
      end

      BUTTERFLY_WRITE_O: begin
        if (butterfly_loop_finished && base_loop_finished && stage_loop_finished) begin
          next_state = FINISH;
        end
        else if (butterfly_loop_finished && base_loop_finished) begin
          next_state = BUTTERFLY_READ;
        end
        else begin
          next_state = BUTTERFLY_READ;
        end
      end

      FINISH: begin
        if (!enable_accel) begin        // Disable the accelerator to start a new FFT
          next_state = INIT;
        end
        else begin
          next_state = FINISH;          // End of FFT process
        end
      end

      default: begin
        next_state = INIT;
      end
    endcase
  end

  always @(posedge clk) begin
    if (reset_accel) begin
      // Stage loop -- pre-initialization of loop variables corresponding to the first iteration of the loop
      stage <= 'd1;
      m <= 'd2;
      half <= 'd1;
      twiddle_prefetch_addr <= 'd0;
      // Base loop -- pre-initialization of loop variables corresponding to the first iteration of the loop
      base <= 'd0;
      // Butterfly loop -- pre-initialization of loop variables corresponding to the first iteration of the loop
      k <= 'd0;
      // Reset input/output FSM registers
      u_re <= 'd0;
      u_im <= 'd0;
      v_re <= 'd0;
      v_im <= 'd0;
      e_re <= 'd0;
      e_im <= 'd0;
      o_re <= 'd0;
      o_im <= 'd0;
      // FSM accelerator flag
      fft_finished <= 1'b0;
    end
    else begin
      case (current_state)
        INIT: begin
          // Stage loop
          stage <= 'd1;
          m <= 'd2;
          half <= 'd1;
          twiddle_prefetch_addr <= 'd0;
          // Base loop
          base <= 'b0;
          w_re <= 'b1 << SCALE;
          w_im <= 'd0;
          // Butterfly loop
          k <= 'd0;
          // u_re <= 'd0;
          // u_im <= 'd0;
          // v_re <= 'd0;
          // v_im <= 'd0;
          // e_re <= 'd0;
          // e_im <= 'd0;
          // o_re <= 'd0;
          // o_im <= 'd0;
          fft_finished <= 1'b0;
        end

        BUTTERFLY_READ: begin
          u_re <= accel_mem_rdata_re_a;
          u_im <= accel_mem_rdata_im_a;
          v_re <= accel_mem_rdata_re_b;
          v_im <= accel_mem_rdata_im_b;
        end

        BUTTERFLY_COMPUTE: begin
          e_re <= u_re + t_re;
          e_im <= u_im + t_im;
          o_re <= u_re - t_re;
          o_im <= u_im - t_im;
        end

        BUTTERFLY_WRITE_E_AND_PREFETCH_W: begin
          if (!trivial_state && next_k < half) begin
            w_re <= accel_mem_rdata_re_b;
            w_im <= accel_mem_rdata_im_b;
          end
        end

        BUTTERFLY_WRITE_O: begin
          if (butterfly_loop_finished && base_loop_finished) begin
            // Increment state loop
            stage <= next_stage;
            half <= m;
            if (!trivial_state) begin
              twiddle_prefetch_addr <= twiddle_prefetch_addr + (half - 1);
            end
            m <= m<<1;
            // Made tweak here for compute
            // Reset base loop
            base <= 'd0;
            // Reset butterfly loop
            k <= 'd0;
          end
          else if (butterfly_loop_finished) begin
            // Increment base loop
            base <= next_base;
            // Reset butterfly loop
            k <= 'd0;
          end
          else begin
            // Do nothing for state loop
            // Do nothing for base loop
            // Increment butterfly loop
            k <= next_k;
          end
        end

        FINISH: begin
          fft_finished <= 1'b1;   // End of fft process
        end

        default: ;
      endcase
    end
  end

  // assign input_data_base_addr = num_fft_stages;
  assign input_data_base_addr = num_twiddles;
  assign mem_index_base_k = base + k;
  assign mem_index_base_k_plus_half = base + k + half;

  always @(*) begin
    //accel_mem_wstrb = ((current_state == BUTTERFLY_WRITE_E_AND_PREFETCH_W) || (current_state == BUTTERFLY_WRITE_O)) ? 4'b1111 : 4'b0000;
    accel_mem_wstrb = ((current_state == BUTTERFLY_WRITE_E_AND_PREFETCH_W) || (current_state == BUTTERFLY_WRITE_O)) ? 3'b111 : 3'b000;
    accel_mem_wdata_re = 'd0;
    accel_mem_wdata_im = 'd0;
    accel_mem_addr_a = 'd0;
    accel_mem_addr_b = 'd0;
    t_re = 'd0;
    t_im = 'd0;

    case (current_state)
      INIT: ;

      BUTTERFLY_READ: begin
        accel_mem_addr_a = input_data_base_addr + mem_index_base_k;
        accel_mem_addr_b = input_data_base_addr + mem_index_base_k_plus_half;
      end
      
      BUTTERFLY_COMPUTE: begin
        if (k == 0) begin
          // w=1 always at start of every group, ALL stages
          t_re = v_re;
          t_im = v_im;

        end
        else if (trivial_state) begin
          case(k[1:0])
            2'b01: begin
                t_re = v_im;
                t_im = -v_re;
            end
            2'b10: begin
                t_re = -v_re;
                t_im = -v_im;
            end
            2'b11: begin
                t_re = -v_im;
                t_im = v_re;
            end
            default: begin 
              t_re = v_re;
              t_im = v_im;
            end               
        endcase

        end
        else begin
          mult_re = (iso_v_re * iso_w_re - iso_v_im * iso_w_im); 
          mult_im = (iso_v_re * iso_w_im + iso_v_im * iso_w_re); 
          // Full multiply for non-trivial stages, k>0
          t_re = mult_re >>> SCALE;
          t_im = mult_im >>> SCALE;
        end
      end

      BUTTERFLY_WRITE_E_AND_PREFETCH_W: begin
        accel_mem_addr_a = input_data_base_addr + mem_index_base_k;
        accel_mem_wdata_re = e_re;
        accel_mem_wdata_im = e_im;
        if (!trivial_state && next_k < half) begin
          accel_mem_addr_b = twiddle_prefetch_addr + k;
        end
      end

      BUTTERFLY_WRITE_O: begin
        accel_mem_addr_a = input_data_base_addr + mem_index_base_k_plus_half;
        accel_mem_wdata_re = o_re;
        accel_mem_wdata_im = o_im;
      end

      FINISH: ;

      default: ;
    endcase
  end
endmodule
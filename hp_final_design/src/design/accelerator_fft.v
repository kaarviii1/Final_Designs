module accelerator_fft #(
    parameter integer LOG_MAX_N   = 32,                
    parameter integer MEM_WIDTH = 32,  
    parameter integer ADDR_WIDTH = 32,  
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)  
) (
    input wire clk,
    input wire resetn,

    input wire reset_accel,
    input wire enable_accel,

    input wire [LOG_MAX_N-1:0] num_data,  
    input  wire [LOG_MAX_FFT_STAGES-1:0] num_fft_stages,          

    output reg  [ 4-1:0] accel_mem_wstrb,
    output reg [32-1:0] accel_mem_addr,
    input wire [32-1:0] accel_mem_rdata_re,
    output reg [32-1:0] accel_mem_wdata_re,
    input wire [32-1:0] accel_mem_rdata_im,
    output reg [32-1:0] accel_mem_wdata_im,

    output reg fft_finished
);

  localparam INIT = 3'b000;
  localparam READ_W_M = 3'b011;
  localparam BUTTERFLY_READ_U = 3'b001;
  localparam BUTTERFLY_READ_V = 3'b010;
  localparam BUTTERFLY_COMPUTE = 3'b110;
  localparam BUTTERFLY_WRITE_E = 3'b111;
  localparam BUTTERFLY_WRITE_O = 3'b101;
  localparam FINISH = 3'b100;

  reg [2:0] current_state;
  reg [2:0] next_state;

  reg [LOG_MAX_N-1:0] m;
  reg [LOG_MAX_FFT_STAGES-1:0] stage;
  reg [LOG_MAX_N-1:0] base;
  reg [LOG_MAX_N-2:0] k;
  reg [LOG_MAX_N-2:0] half;

  reg signed [MEM_WIDTH-1:0] w_re;
  reg signed [MEM_WIDTH-1:0] w_im;
  reg signed [MEM_WIDTH-1:0] w_m_re;
  reg signed [MEM_WIDTH-1:0] w_m_im;
  reg signed [MEM_WIDTH-1:0] u_re;
  reg signed [MEM_WIDTH-1:0] u_im;
  reg signed [MEM_WIDTH-1:0] v_re;
  reg signed [MEM_WIDTH-1:0] v_im;
  reg signed [MEM_WIDTH-1:0] e_re;
  reg signed [MEM_WIDTH-1:0] e_im;
  reg signed [MEM_WIDTH-1:0] o_re;
  reg signed [MEM_WIDTH-1:0] o_im;
  
  wire signed [MEM_WIDTH-1:0] iso_v_re;
  wire signed [MEM_WIDTH-1:0] iso_v_im;
  wire signed [MEM_WIDTH-1:0] iso_w_re;
  wire signed [MEM_WIDTH-1:0] iso_w_im;
  wire signed [MEM_WIDTH-1:0] iso_w_m_re;
  wire signed [MEM_WIDTH-1:0] iso_w_m_im;

  wire [LOG_MAX_FFT_STAGES-1:0] next_stage;
  wire [LOG_MAX_N-1:0] next_base;
  wire [LOG_MAX_N-2:0] next_k;
  wire [ADDR_WIDTH-1:0] input_data_base_addr;
  wire [ADDR_WIDTH-1:0] mem_index_base_k;
  wire [ADDR_WIDTH-1:0] mem_index_base_k_plus_half;
  
  reg signed [MEM_WIDTH-1:0] t_re;
  reg signed [MEM_WIDTH-1:0] t_im;
  reg signed [MEM_WIDTH-1:0] next_w_re;
  reg signed [MEM_WIDTH-1:0] next_w_im;

  wire trivial_state;
  wire butterfly_loop_finished;
  wire base_loop_finished;
  wire stage_loop_finished;

  localparam SCALE = 12;

  always @(posedge clk) begin
    if (reset_accel) begin
      current_state <= INIT;
    end
    else begin
      current_state <= next_state;
    end
  end

  assign butterfly_loop_finished = (next_k == half);
  assign base_loop_finished = (next_base == num_data);
  assign stage_loop_finished = (next_stage > num_fft_stages);
  assign next_k = k + 1;
  assign next_base = base + m;
  assign next_stage = stage + 1;
  assign trivial_state = (m <= 4);
  
  assign iso_v_re = (current_state == BUTTERFLY_COMPUTE) ? v_re : 'd0;
  assign iso_v_im = (current_state == BUTTERFLY_COMPUTE) ? v_im : 'd0;
  assign iso_w_re = (current_state == BUTTERFLY_COMPUTE) ? w_re : 'd0;
  assign iso_w_im = (current_state == BUTTERFLY_COMPUTE) ? w_im : 'd0;
  assign iso_w_m_re = (current_state == BUTTERFLY_COMPUTE) ? w_m_re : 'd0;
  assign iso_w_m_im = (current_state == BUTTERFLY_COMPUTE) ? w_m_im : 'd0;
  
  always @(*) begin
    case (current_state)
      INIT: begin
        if (enable_accel) begin
          if (num_data[LOG_MAX_N-1:1] == 0) begin
            next_state = FINISH;
          end
          else begin
            next_state = READ_W_M;
          end
        end
        else begin
          next_state = INIT;
        end
      end

      READ_W_M: begin
        next_state = BUTTERFLY_READ_U;
      end

      BUTTERFLY_READ_U: begin
        next_state = BUTTERFLY_READ_V;
      end

      BUTTERFLY_READ_V: begin
        next_state = BUTTERFLY_COMPUTE;
      end

      BUTTERFLY_COMPUTE: begin
        next_state = BUTTERFLY_WRITE_E;
      end

      BUTTERFLY_WRITE_E: begin
        next_state = BUTTERFLY_WRITE_O;
      end

      BUTTERFLY_WRITE_O: begin
        if (butterfly_loop_finished && base_loop_finished && stage_loop_finished) begin
          next_state = FINISH;
        end
        else if (butterfly_loop_finished && base_loop_finished) begin
          next_state = READ_W_M;
        end
        else begin
          next_state = BUTTERFLY_READ_U;
        end
      end

      FINISH: begin
        if (!enable_accel) begin
          next_state = INIT;
        end
        else begin
          next_state = FINISH;
        end
      end

      default: begin
        next_state = INIT;
      end
    endcase
  end

  always @(posedge clk) begin
    if (reset_accel) begin
      stage <= 'd1;
      m <= 'd2;
      half <= 'd1;
      base <= 'd0;
      w_re <= 'd1 << SCALE;
      w_im <= 'd0;
      k <= 'd0;
      w_m_re <= 'd0; w_m_im <= 'd0;
      u_re <= 'd0; u_im <= 'd0;
      v_re <= 'd0; v_im <= 'd0;
      e_re <= 'd0; e_im <= 'd0;
      o_re <= 'd0; o_im <= 'd0;
      fft_finished <= 1'b0;
    end
    else begin
      case (current_state)
        INIT: begin
          stage <= 'd1; m <= 'd2; half <= 'd1;
          base <= 'd0; w_re <= 'd1 << SCALE; w_im <= 'd0;
          k <= 'd0;
          w_m_re <= 'd0; w_m_im <= 'd0;
          u_re <= 'd0; u_im <= 'd0;
          v_re <= 'd0; v_im <= 'd0;
          e_re <= 'd0; e_im <= 'd0;
          o_re <= 'd0; o_im <= 'd0;
          fft_finished <= 1'b0;
        end

        READ_W_M: begin
          w_m_re <= accel_mem_rdata_re;
          w_m_im <= accel_mem_rdata_im;
        end

        BUTTERFLY_READ_U: begin
          u_re <= accel_mem_rdata_re;
          u_im <= accel_mem_rdata_im;
        end

        BUTTERFLY_READ_V: begin
          v_re <= accel_mem_rdata_re;
          v_im <= accel_mem_rdata_im;
        end

        BUTTERFLY_COMPUTE: begin
          e_re <= u_re + t_re;
          e_im <= u_im + t_im;
          o_re <= u_re - t_re;
          o_im <= u_im - t_im;
          w_re <= next_w_re;
          w_im <= next_w_im;
        end

        BUTTERFLY_WRITE_O: begin
          if (butterfly_loop_finished && base_loop_finished) begin
            stage <= next_stage;
            half <= m;
            m <= m<<1;
            base <= 'd0;
            w_re <= 'd1 << SCALE;
            w_im <= 'd0;
            k <= 'd0;
          end
          else if (butterfly_loop_finished) begin
            base <= next_base;
            w_re <= 'd1 << SCALE;
            w_im <= 'd0;
            k <= 'd0;
          end
          else begin
            k <= next_k;
          end
        end

        FINISH: begin
          fft_finished <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  assign input_data_base_addr = num_fft_stages;
  assign mem_index_base_k = base + k;
  assign mem_index_base_k_plus_half = base + k + half;

  always @(*) begin
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata_re = 'd0;
    accel_mem_wdata_im = 'd0;
    accel_mem_addr = 'd0;
    t_re = 'd0; t_im = 'd0;
    next_w_re = 'd0; next_w_im = 'd0;

    case (current_state)
      READ_W_M: begin
        accel_mem_addr = stage - 1;
      end
      BUTTERFLY_READ_U: begin
        accel_mem_addr = input_data_base_addr + mem_index_base_k;
      end
      BUTTERFLY_READ_V: begin
        accel_mem_addr = input_data_base_addr + mem_index_base_k_plus_half;
      end
      BUTTERFLY_COMPUTE: begin
        if (k == 0) begin
          t_re = v_re; t_im = v_im;
          if (!trivial_state) begin
            next_w_re = (w_re * w_m_re - w_im * w_m_im) >>> SCALE;
            next_w_im = (w_re * w_m_im + w_im * w_m_re) >>> SCALE;
          end else begin
            next_w_re = w_re; next_w_im = w_im;
          end
        end else if (trivial_state) begin
          case(k[1:0])
            2'b01: begin t_re = v_im; t_im = -v_re; end
            2'b10: begin t_re = -v_re; t_im = -v_im; end
            2'b11: begin t_re = -v_im; t_im = v_re; end
            default: begin t_re = v_re; t_im = v_im; end               
          endcase
          next_w_re = w_re; next_w_im = w_im;
        end else begin
          t_re = (iso_v_re * iso_w_re - iso_v_im * iso_w_im) >>> SCALE;
          t_im = (iso_v_re * iso_w_im + iso_v_im * iso_w_re) >>> SCALE;
          next_w_re = (iso_w_re * iso_w_m_re - iso_w_im * iso_w_m_im) >>> SCALE;
          next_w_im = (iso_w_re * iso_w_m_im + iso_w_im * iso_w_m_re) >>> SCALE;
        end
      end
      BUTTERFLY_WRITE_E: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr = input_data_base_addr + mem_index_base_k;
        accel_mem_wdata_re = e_re;
        accel_mem_wdata_im = e_im;
      end
      BUTTERFLY_WRITE_O: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr = input_data_base_addr + mem_index_base_k_plus_half;
        accel_mem_wdata_re = o_re;
        accel_mem_wdata_im = o_im;
      end
      default: ;
    endcase
  end

endmodule

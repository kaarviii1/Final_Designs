#include "uart.h"
#include "flash.h"
#include "fft.h"

// Define accelerator registers
#define REG_CONFIG_AND_STATUS  (*(volatile uint32_t*)0x03000000)
#define REG_NUMBER_OF_ENTRIES  (*(volatile uint32_t*)0x03000004)
#define REG_NUMBER_OF_BITS     (*(volatile uint32_t*)0x03000008)
#define REG_NUMBER_OF_TWIDDLES (*(volatile uint32_t*)0x0300000C)
#define ACCEL_SRAM_START_ADDR                        0x03000010

// Define accelerator control/status (CSR) bits
#define MASK_CSR_RESET 1 << 0
#define MASK_CSR_ENABLE 1 << 1
#define MASK_CSR_DONE  1 << 2

#define SCALE 12

static int read_dec_entry_from_accelerator_sram(int index) {
	// i * 4 because each entry (signed 32-bit integer) is 4 bytes
	uint32_t sram_address = ACCEL_SRAM_START_ADDR + index*4;

	return (*(volatile int*)(sram_address));
}

static void accelerated_fft(int n, int chunks, int bits) { 
	// Initialize accelerator
	REG_CONFIG_AND_STATUS = 0;
	REG_NUMBER_OF_ENTRIES = 0;

	// Reset accelerator (this additional reset is necessary when processing multiple chunks)
	REG_CONFIG_AND_STATUS = REG_CONFIG_AND_STATUS | MASK_CSR_RESET;  // Set reset bit
	REG_CONFIG_AND_STATUS &= ~MASK_CSR_RESET; // Clear reset bit

	int entries_per_chunk = n / chunks; // 32 real samples
	int half_of_entries_per_chunk = entries_per_chunk / 2; // 16 complex packed samples for real FFT
	int half_of_bits = bits - 1; // real FFT reduce the number of stages by 1

	// Set number of entries
	// REG_NUMBER_OF_ENTRIES = entries_per_chunk;
	REG_NUMBER_OF_ENTRIES = half_of_entries_per_chunk;

    // Set number of bits
    // REG_NUMBER_OF_BITS = bits;
	REG_NUMBER_OF_BITS = half_of_bits;

	// Due to the number of values stored at index 0 and the number
	// of chunks stored at index 1, the twiddles start at index 2
    int flash_offset = 2; 
	int num_of_fft_twiddles = read_dec_entry_from_flash(flash_offset);
	REG_NUMBER_OF_TWIDDLES = num_of_fft_twiddles;

	flash_offset++;

	/*
	// Write twiddles to SRAM of accelerator
	for (int i = 0; i < 2 * bits; i++) {
		// i * 4 because each entry (signed 32-bit integer) is 4 bytes
		uint32_t sram_address = ACCEL_SRAM_START_ADDR + i*4;

		(*(volatile int*)(sram_address)) = read_dec_entry_from_flash(flash_offset + i);
	}

    // We read starting from i + 2 + 2 * bits, because those 2 * bits entries were the twiddles
    flash_offset += 2 * bits;
	*/

	// Write twiddles to SRAM of accelerator
	for (int i = 0; i < 2* num_of_fft_twiddles; i++) 
	{
		// i * 4 because each entry (signed 32-bit integer) is 4 bytes
		uint32_t sram_address = ACCEL_SRAM_START_ADDR + i*4;

		(*(volatile int*)(sram_address)) = read_dec_entry_from_flash(flash_offset + i);
	}

    // We read starting from i + 3 + 2 * num_of_fft_twiddles, because those num_of_fft_twiddles entries were the twiddles
    flash_offset += 2 * num_of_fft_twiddles;
	
	int unpack_twiddle_flash_offset = flash_offset;
    flash_offset += 2 * half_of_entries_per_chunk;  // skip 16 unpack twiddle pairs

	for (int chunk = 0; chunk < chunks; chunk++) {
		// Reset accelerator
		REG_CONFIG_AND_STATUS = REG_CONFIG_AND_STATUS | MASK_CSR_RESET;  // Set reset bit
		REG_CONFIG_AND_STATUS &= ~MASK_CSR_RESET; // Clear reset bit

		/*
		// Write input array to SRAM of accelerator
		for (int i = 0; i < entries_per_chunk; i++) {
			// The inputs are composed of a real part only: Write the real part.
			// i * 4 because each entry (signed 32-bit integer) is 4 bytes
			// uint32_t sram_address = ACCEL_SRAM_START_ADDR + (2 * bits + 2 * i) * 4;
			 uint32_t sram_address = ACCEL_SRAM_START_ADDR + (2 * num_of_fft_twiddles + 2 * i) * 4;

			int bit_reverse_i = bit_reverse(i, bits);
			(*(volatile int*)(sram_address)) = read_dec_entry_from_flash(flash_offset + bit_reverse_i);
			
			// As the algorithm is in-place, we set the imaginary part to 0.
			sram_address += 4;
			(*(volatile int*)(sram_address)) = 0;
		}
		*/

		// z[n] = x[2n] + j*x[2n+1], bit-reversed into SRAM
        for (int i = 0; i < half_of_entries_per_chunk; i++) {
            int bit_reverse_i = bit_reverse(i, half_of_bits);  // 4-bit reversal for N/2=16

            // SRAM address for packed entry at bit-reversed position
			// The inputs are composed of a real part only: Write the real part.
			// i * 4 because each entry (signed 32-bit integer) is 4 bytes
			// uint32_t sram_address = ACCEL_SRAM_START_ADDR + (2 * bits + 2 * i) * 4;
            uint32_t sram_addr_re = ACCEL_SRAM_START_ADDR + (2 * num_of_fft_twiddles + 2 * bit_reverse_i) * 4;
            uint32_t sram_addr_im = sram_addr_re + 4;

            // Pack: real part = x[2i], imaginary part = x[2i+1]
            (*(volatile int*)(sram_addr_re)) = read_dec_entry_from_flash(flash_offset + 2 * i);
            (*(volatile int*)(sram_addr_im)) = read_dec_entry_from_flash(flash_offset + 2 * i + 1);
        }


		// Start accelerator
		REG_CONFIG_AND_STATUS |= MASK_CSR_ENABLE;

		// Wait for accelerator to finish
		while (!(REG_CONFIG_AND_STATUS & MASK_CSR_DONE));

		// Disable accelerator
		REG_CONFIG_AND_STATUS &= ~MASK_CSR_ENABLE;

		flash_offset += entries_per_chunk;

		// In the accelerator SRAM, the the #values to FFT and #chunks are not stored
		// int sram_offset = 2 * bits;
		int sram_offset = 2 * num_of_fft_twiddles;

		/*
		for (int i = 0; i < entries_per_chunk; i++) {
			int real = read_dec_entry_from_accelerator_sram(sram_offset + 2 * i);
			// int imag = 0;
			int imag = read_dec_entry_from_accelerator_sram(sram_offset + 2 * i + 1);

			print_str("  ");
			print_dec(real);
			print_str(" + ");
			print_dec(imag);
			print_str("j,\n");
		}
		*/

		// Print X[0] to X[15]
        for (int k = 0; k < half_of_entries_per_chunk; k++) {
            // Read Z[k]
            int Zk_re = read_dec_entry_from_accelerator_sram(sram_offset + 2 * k);
            int Zk_im = read_dec_entry_from_accelerator_sram(sram_offset + 2 * k + 1);

            // Read Z*[conj_idx] where conj_idx = (16-k) % 16
            int conj_idx = (half_of_entries_per_chunk - k) % half_of_entries_per_chunk;
            int Zc_re = read_dec_entry_from_accelerator_sram(sram_offset + 2 * conj_idx);
            int Zc_im = read_dec_entry_from_accelerator_sram(sram_offset + 2 * conj_idx + 1);

            // A[k] = (Z[k] + Z*[conj_idx]) / 2
            int A_re = (Zk_re + Zc_re) >> 1;
            int A_im = (Zk_im - Zc_im) >> 1;

            // B[k] = -j * (Z[k] - Z*[conj_idx]) / 2
            int B_re = (Zk_im + Zc_im) >> 1;
            int B_im = (Zc_re - Zk_re) >> 1;

            // Read unpack twiddle W_32^k from flash
            int W_re = read_dec_entry_from_flash(unpack_twiddle_flash_offset + 2 * k);
            int W_im = read_dec_entry_from_flash(unpack_twiddle_flash_offset + 2 * k + 1);

            // WB = W * B
            int WB_re = ((W_re * B_re) - (W_im * B_im)) >> SCALE;
            int WB_im = ((W_re * B_im) + (W_im * B_re)) >> SCALE;

            // X[k] = A[k] + WB
            print_str("  ");
            print_dec(A_re + WB_re);
            print_str(" + ");
            print_dec(A_im + WB_im);
            print_str("j,\n");
        }

        // Print X[16] to X[31]
        for (int k = 0; k < half_of_entries_per_chunk; k++) {
            int Zk_re = read_dec_entry_from_accelerator_sram(sram_offset + 2 * k);
            int Zk_im = read_dec_entry_from_accelerator_sram(sram_offset + 2 * k + 1);

            int conj_idx = (half_of_entries_per_chunk - k) % half_of_entries_per_chunk;
            int Zc_re = read_dec_entry_from_accelerator_sram(sram_offset + 2 * conj_idx);
            int Zc_im = read_dec_entry_from_accelerator_sram(sram_offset + 2 * conj_idx + 1);

            int A_re = (Zk_re + Zc_re) >> 1;
            int A_im = (Zk_im - Zc_im) >> 1;

            int B_re = (Zk_im + Zc_im) >> 1;
            int B_im = (Zc_re - Zk_re) >> 1;

            int W_re = read_dec_entry_from_flash(unpack_twiddle_flash_offset + 2 * k);
            int W_im = read_dec_entry_from_flash(unpack_twiddle_flash_offset + 2 * k + 1);

            int WB_re = ((W_re * B_re) - (W_im * B_im)) >> SCALE;
            int WB_im = ((W_re * B_im) + (W_im * B_re)) >> SCALE;

            // X[k+16] = A[k] - WB
            print_str("  ");
            print_dec(A_re - WB_re);
            print_str(" + ");
            print_dec(A_im - WB_im);
            print_str("j,\n");
        }
	}
}

static void init_picosoc() {
	#define SRAM_ADDR_HEAD 0x00000000
	#define SRAM_ADDR_END  0x000003FF

    // Initialize SRAM (Otherwise the post-synthesis/layout simulation will fail, finished within 17192 cycles)
    volatile uint32_t* sram_addr = 0x00000000;
    for (sram_addr = 0; sram_addr <= (volatile uint32_t*) SRAM_ADDR_END; sram_addr += 4) {
        *sram_addr = 0;
    }

    // Initialize UART
    init_uart();
}

void main(void)
{
	// Initialize PicoSoC
	init_picosoc();

    int n = read_dec_entry_from_flash(0);
	int chunks = read_dec_entry_from_flash(1);
    int bits = flog2(n / chunks);

	print_str("\nFrequency domain output: \n[\n");

	// We do not need to pass the array and its size to the accelerated_fft function
	// as this information is read from the flash memory by the function itself
	accelerated_fft(n, chunks, bits);

	print_str("]\n");

    // End of Program
    print_char(-1);
}

/*
 * Define the entry point of the program.
 */
__attribute__((section(".text.start")))
void _start(void)
{
	main();
}
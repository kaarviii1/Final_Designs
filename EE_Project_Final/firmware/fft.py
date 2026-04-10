import cmath
import math
from typing import List


SCALE = 12
MAX_N_PER_FFT = 32
HALF_MAX_N_PER_FFT = 16


FFT_TWIDDLES = []

for stage in range(1, round(math.log2(HALF_MAX_N_PER_FFT)) + 1):
    m = 1 << stage  # m = 2, 4, 8, ..., n
    half = m // 2
    is_trivial_stage = (m <= 4)
    
    if (is_trivial_stage):
        continue
    
    for k in range(1, half):
        W = cmath.exp(-2j * cmath.pi * k / m)
        W_scaled = complex(round(W.real * (1<<SCALE)), round(W.imag * (1<<SCALE)))
        FFT_TWIDDLES.append(W_scaled)

NUM_FFT_TWIDDLES = len(FFT_TWIDDLES)


REAL_FFT_TWIDDLES = []

for k in range(HALF_MAX_N_PER_FFT):
    W = cmath.exp(-2j * cmath.pi * k / MAX_N_PER_FFT)
    W_scaled = complex(round(W.real * (1<<SCALE)), round(W.imag * (1<<SCALE)))
    REAL_FFT_TWIDDLES.append(W_scaled)

NUM_REAL_FFT_TWIDDLES = len(REAL_FFT_TWIDDLES)


def complex_mult(in1: complex, in2: complex) -> complex:
    a = int(in1.real)
    b = int(in1.imag)
    c = int(in2.real)
    d = int(in2.imag)

    return complex((a * c - b * d) >> SCALE, (a * d + b * c) >> SCALE)



def flog2(x: int) -> int:
    r = 0

    while x > 1:
        r += 1
        x = x >> 1

    return r


def bit_reverse(i: int, bits: int) -> int:
    r: int = 0
    for _ in range(bits):
        r = (r << 1) | (i & 1)
        i >>= 1
    return r


def fft(x: List[complex]) -> List[complex]:
    n = len(x)
    bits = flog2(n)

    # Step 1: bit-reversal permutation
    X = [0j] * n

    for i in range(n):
        X[bit_reverse(i, bits)] = x[i]

    twiddle_base = 0
    # Step 2: iterative FFT stages
    for stage in range(1, bits + 1):
        m = 1 << stage  # m = 2, 4, 8, ..., n
        half = m // 2
        is_trivial_stage = (m <= 4)
        
        for base in range(0, n, m):
            for k in range(half):
                v = X[base + k + half]
                
                if (k == 0):
                    t = v
                elif (is_trivial_stage):
                    v_re = int(v.real)
                    v_im = int(v.imag)
                    if (k % 4 == 0):
                        t = v
                    elif (k % 4 == 1):
                        t = complex(v_im, -v_re)
                    elif (k % 4 == 2):
                        t = complex(-v_re, -v_im)
                    else:
                        t = complex(-v_im, v_re)
                else:
                    w = FFT_TWIDDLES[twiddle_base + k - 1]
                    t = complex_mult(w, v)
                
                u = X[base + k]
                X[base + k] = u + t
                X[base + k + half] = u - t
                
        if (not is_trivial_stage):
            twiddle_base += half - 1

    return X

def real_fft(x: List[complex]) -> List[complex]:
    n = len(x)
    
    z = []
    for i in range(HALF_MAX_N_PER_FFT):
        z_i_re = x[2 * i]
        z_i_im = x[2 * i + 1]
        if isinstance(z_i_re, complex):
            z_i_re = z_i_re.real
        else:
            z_i_re = z_i_re
        if isinstance(z_i_im, complex):
            z_i_im = z_i_im.real
        else:
            z_i_im = z_i_im
        z.append(complex(z_i_re, z_i_im))
        
    Z = fft(z)
    
    X = [0j] * n
    
    for k in range(HALF_MAX_N_PER_FFT):
        k_c = (HALF_MAX_N_PER_FFT - k) % HALF_MAX_N_PER_FFT
        Z_k_re = Z[k].real
        Z_k_im = Z[k].imag
        Z_k_c_re = Z[k_c].real
        Z_k_c_im = Z[k_c].imag
        
        E_k_re = int(Z_k_re + Z_k_c_re) >> 1
        E_k_im = int(Z_k_im - Z_k_c_im) >> 1
        
        O_k_re = int(Z_k_im + Z_k_c_im) >> 1
        O_k_im = int(Z_k_c_re - Z_k_re) >> 1
        
        O_k = complex(O_k_re, O_k_im)
        W_k = REAL_FFT_TWIDDLES[k]
        WO = complex_mult(W_k, O_k)
        WO_re = WO.real
        WO_im = WO.imag
        
        X[k] = complex((E_k_re + WO_re), (E_k_im + WO_im))
        X[k+HALF_MAX_N_PER_FFT] = complex((E_k_re - WO_re), (E_k_im - WO_im))
    return X


def inv_dft(x: List[complex]) -> List[complex]:
    n = len(x)
    X = [0j] * n

    for k in range(n):
        sum_val = 0j
        for t in range(n):
            angle = 2j * cmath.pi * t * k / n
            sum_val += x[t] * cmath.exp(angle)
        X[k] = sum_val / n

    return X


"""
import cmath
import math
from typing import List


SCALE = 12
MAX_N_PER_FFT = 32
TWIDDLES = []


for stage in range(1, round(math.log2(MAX_N_PER_FFT)) + 1):
    m = 1 << stage  # m = 2, 4, 8, ..., n
    half = m // 2
    is_trivial_stage = (m <= 4)
    
    if (is_trivial_stage):
        continue
    
    for k in range(1, half):
        W = cmath.exp(-2j * cmath.pi * k / m)
        W_scaled = complex(round(W.real * (1<<SCALE)), round(W.imag * (1<<SCALE)))
        TWIDDLES.append(W_scaled)

NUM_TWIDDLES = len(TWIDDLES)

def complex_mult(in1: complex, in2: complex) -> complex:
    a = int(in1.real)
    b = int(in1.imag)
    c = int(in2.real)
    d = int(in2.imag)

    return complex((a * c - b * d) >> SCALE, (a * d + b * c) >> SCALE)


def flog2(x: int) -> int:
    r = 0

    while x > 1:
        r += 1
        x = x >> 1

    return r


def bit_reverse(i: int, bits: int) -> int:
    r: int = 0
    for _ in range(bits):
        r = (r << 1) | (i & 1)
        i >>= 1
    return r


def fft(x: List[complex]) -> List[complex]:
    n = len(x)
    bits = flog2(n)

    # Step 1: bit-reversal permutation
    X = [0j] * n

    for i in range(n):
        X[bit_reverse(i, bits)] = x[i]

    twiddle_base = 0
    # Step 2: iterative FFT stages
    for stage in range(1, bits + 1):
        m = 1 << stage  # m = 2, 4, 8, ..., n
        half = m // 2
        is_trivial_stage = (m <= 4)
        
        for base in range(0, n, m):
            for k in range(half):
                v = X[base + k + half]
                
                if (k == 0):
                    t = v
                elif (is_trivial_stage):
                    v_re = int(v.real)
                    v_im = int(v.imag)
                    if (k % 4 == 0):
                        t = v
                    elif (k % 4 == 1):
                        t = complex(v_im, -v_re)
                    elif (k % 4 == 2):
                        t = complex(-v_re, -v_im)
                    else:
                        t = complex(-v_im, v_re)
                else:
                    w = TWIDDLES[twiddle_base + k - 1]
                    t = complex_mult(w, v)
                
                u = X[base + k]
                X[base + k] = u + t
                X[base + k + half] = u - t
                
        if (not is_trivial_stage):
            twiddle_base += half - 1

    return X


def inv_dft(x: List[complex]) -> List[complex]:
    n = len(x)
    X = [0j] * n

    for k in range(n):
        sum_val = 0j
        for t in range(n):
            angle = 2j * cmath.pi * t * k / n
            sum_val += x[t] * cmath.exp(angle)
        X[k] = sum_val / n

    return X

"""
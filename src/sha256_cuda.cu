#include "sha256_cuda.cuh"

__device__ void sha256_init(SHA256_CTX* ctx) {
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
    ctx->count = 0;
}

__device__ void sha256_transform(uint32_t* state, const uint8_t* block) {
    uint32_t w[64];
    uint32_t a, b, c, d, e, f, g, h;
    uint32_t t1, t2;
    int i;

    // Copy block into w[0..15]
    for (i = 0; i < 16; i++) {
        w[i] = (block[i*4] << 24) | (block[i*4+1] << 16) |
               (block[i*4+2] << 8) | (block[i*4+3]);
    }

    // Extend into w[16..63]
    for (i = 16; i < 64; i++) {
        w[i] = SIG1(w[i-2]) + w[i-7] + SIG0(w[i-15]) + w[i-16];
    }

    // Initialize working variables
    a = state[0];
    b = state[1];
    c = state[2];
    d = state[3];
    e = state[4];
    f = state[5];
    g = state[6];
    h = state[7];

    // Main loop
    for (i = 0; i < 64; i++) {
        t1 = h + EP1(e) + CH(e,f,g) + K[i] + w[i];
        t2 = EP0(a) + MAJ(a,b,c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    // Update state
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

__device__ void sha256_update(SHA256_CTX* ctx, const uint8_t* data, size_t len) {
    size_t i;
    size_t index = ctx->count & 0x3f;
    ctx->count += len;

    for (i = 0; i < len; i++) {
        ctx->buffer[index++] = data[i];

        if (index == 64) {
            sha256_transform(ctx->state, ctx->buffer);
            index = 0;
        }
    }
}

__device__ void sha256_final(uint8_t* digest, SHA256_CTX* ctx) {
    uint8_t bits[8];
    uint32_t index = ctx->count & 0x3f;
    uint32_t padlen = (index < 56) ? (56 - index) : (120 - index);
    uint64_t count_bits = ctx->count * 8;

    // Convert count to bits and store big-endian
    for (int i = 7; i >= 0; i--) {
        bits[i] = count_bits & 0xff;
        count_bits >>= 8;
    }

    // Pad with 1 bit followed by zeros
    uint8_t pad = 0x80;
    sha256_update(ctx, &pad, 1);
    pad = 0x00;
    while (padlen > 1) {
        sha256_update(ctx, &pad, 1);
        padlen--;
    }

    // Append length in bits
    sha256_update(ctx, bits, 8);

    // Copy output
    for (int i = 0; i < 8; i++) {
        digest[i*4] = (ctx->state[i] >> 24) & 0xff;
        digest[i*4+1] = (ctx->state[i] >> 16) & 0xff;
        digest[i*4+2] = (ctx->state[i] >> 8) & 0xff;
        digest[i*4+3] = ctx->state[i] & 0xff;
    }
}

__device__ void sha256_hash_optimized(const uint8_t* data, size_t len, uint8_t* digest) {
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, data, len);
    sha256_final(digest, &ctx);
}

__device__ void sha256_batch(const uint8_t* input, size_t data_len, size_t num_items, uint8_t* output) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < num_items) {
        sha256_hash_optimized(input + idx * data_len, data_len, output + idx * SHA256_DIGEST_SIZE);
    }
}

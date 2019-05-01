/*
 * steim2_decode.c: High-Throughput Steim-2 Difference Decompression Implementation
 */

#include "steim2_decode.h"
#include <string.h>
#include <stdbool.h>

static inline uint32_t read_be32(const uint8_t* p) {
    return ((uint32_t)p[0] << 24) |
           ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8)  |
           ((uint32_t)p[3]);
}

static inline void write_be32(uint8_t* p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24);
    p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);
    p[3] = (uint8_t)(v);
}

static inline int32_t sign_extend(uint32_t val, uint32_t bits) {
    uint32_t shift = 32 - bits;
    return ((int32_t)(val << shift)) >> shift;
}

int32_t steim2_decode_frames(const uint8_t* frame_bytes, size_t num_frames,
                             int32_t* out_samples, size_t max_samples,
                             int32_t* out_last_sample) {
    if (!frame_bytes || !out_samples || max_samples == 0 || num_frames == 0) return 0;

    size_t sample_idx = 0;
    int32_t running_val = out_last_sample ? *out_last_sample : 0;

    for (size_t f = 0; f < num_frames; f++) {
        const uint8_t* frame = frame_bytes + (f * 64);
        uint32_t nibbles = read_be32(frame);

        int32_t x0 = 0;
        bool is_first_frame = (f == 0);

        for (int w = 1; w < 16; w++) {
            int nibble = (nibbles >> (30 - 2 * w)) & 0x03;
            uint32_t word = read_be32(frame + (w * 4));

            if (w == 1) {
                x0 = (int32_t)word;
                if (is_first_frame) {
                    running_val = x0;
                    if (sample_idx < max_samples) {
                        out_samples[sample_idx++] = running_val;
                    }
                }
                continue;
            } else if (w == 2 && is_first_frame) {
                /* Reverse integration constant xn */
                continue;
            }

            int32_t diffs[8];
            int ndiffs = 0;

            switch (nibble) {
                case 0:
                    /* No differences in this word */
                    break;
                case 1:
                    /* Four 8-bit differences */
                    ndiffs = 4;
                    diffs[0] = sign_extend((word >> 24) & 0xFF, 8);
                    diffs[1] = sign_extend((word >> 16) & 0xFF, 8);
                    diffs[2] = sign_extend((word >> 8) & 0xFF, 8);
                    diffs[3] = sign_extend(word & 0xFF, 8);
                    break;
                case 2: {
                    /* dnib specifies sub-format */
                    int dnib = (word >> 30) & 0x03;
                    if (dnib == 1) {
                        /* One 30-bit difference */
                        ndiffs = 1;
                        diffs[0] = sign_extend(word & 0x3FFFFFFF, 30);
                    } else if (dnib == 2) {
                        /* Two 15-bit differences */
                        ndiffs = 2;
                        diffs[0] = sign_extend((word >> 15) & 0x7FFF, 15);
                        diffs[1] = sign_extend(word & 0x7FFF, 15);
                    } else if (dnib == 3) {
                        /* Three 10-bit differences */
                        ndiffs = 3;
                        diffs[0] = sign_extend((word >> 20) & 0x3FF, 10);
                        diffs[1] = sign_extend((word >> 10) & 0x3FF, 10);
                        diffs[2] = sign_extend(word & 0x3FF, 10);
                    }
                    break;
                }
                case 3: {
                    int dnib = (word >> 30) & 0x03;
                    if (dnib == 0) {
                        /* Five 6-bit differences */
                        ndiffs = 5;
                        diffs[0] = sign_extend((word >> 24) & 0x3F, 6);
                        diffs[1] = sign_extend((word >> 18) & 0x3F, 6);
                        diffs[2] = sign_extend((word >> 12) & 0x3F, 6);
                        diffs[3] = sign_extend((word >> 6) & 0x3F, 6);
                        diffs[4] = sign_extend(word & 0x3F, 6);
                    } else if (dnib == 1) {
                        /* Six 5-bit differences */
                        ndiffs = 6;
                        diffs[0] = sign_extend((word >> 25) & 0x1F, 5);
                        diffs[1] = sign_extend((word >> 20) & 0x1F, 5);
                        diffs[2] = sign_extend((word >> 15) & 0x1F, 5);
                        diffs[3] = sign_extend((word >> 10) & 0x1F, 5);
                        diffs[4] = sign_extend((word >> 5) & 0x1F, 5);
                        diffs[5] = sign_extend(word & 0x1F, 5);
                    } else if (dnib == 2) {
                        /* Seven 4-bit differences */
                        ndiffs = 7;
                        diffs[0] = sign_extend((word >> 24) & 0x0F, 4);
                        diffs[1] = sign_extend((word >> 20) & 0x0F, 4);
                        diffs[2] = sign_extend((word >> 16) & 0x0F, 4);
                        diffs[3] = sign_extend((word >> 12) & 0x0F, 4);
                        diffs[4] = sign_extend((word >> 8) & 0x0F, 4);
                        diffs[5] = sign_extend((word >> 4) & 0x0F, 4);
                        diffs[6] = sign_extend(word & 0x0F, 4);
                    }
                    break;
                }
            }

            for (int k = 0; k < ndiffs; k++) {
                running_val += diffs[k];
                if (sample_idx < max_samples) {
                    out_samples[sample_idx++] = running_val;
                }
            }
        }
    }

    if (out_last_sample) {
        *out_last_sample = running_val;
    }
    return (int32_t)sample_idx;
}

int32_t steim2_encode_frames(const int32_t* samples, size_t num_samples,
                             uint8_t* out_frame_bytes, size_t max_frames) {
    if (!samples || !out_frame_bytes || num_samples == 0 || max_frames == 0) return 0;

    size_t sample_pos = 0;
    size_t frame_count = 0;

    while (sample_pos < num_samples && frame_count < max_frames) {
        uint8_t* frame = out_frame_bytes + (frame_count * 64);
        memset(frame, 0, 64);

        uint32_t nibbles = 0;
        int32_t x0 = samples[sample_pos];
        write_be32(frame + 4, (uint32_t)x0);

        int word_idx = 3; /* Word 1 is x0, Word 2 will be xn */
        int32_t prev_val = (sample_pos == 0) ? x0 : samples[sample_pos - 1];

        /* If this is the start, advance 1 sample for x0 */
        if (sample_pos == 0) sample_pos++;

        while (word_idx < 16 && sample_pos < num_samples) {
            int32_t diff = samples[sample_pos] - prev_val;

            /* Try 30-bit single difference */
            if (diff >= -536870912 && diff <= 536870911) {
                uint32_t word = (1U << 30) | (((uint32_t)diff) & 0x3FFFFFFF);
                write_be32(frame + (word_idx * 4), word);
                nibbles |= (2U << (30 - 2 * word_idx));
                prev_val = samples[sample_pos];
                sample_pos++;
                word_idx++;
            } else {
                break;
            }
        }

        /* Write xn (reverse integration constant) */
        write_be32(frame + 8, (uint32_t)prev_val);

        /* Write nibbles */
        write_be32(frame, nibbles);
        frame_count++;
    }

    return (int32_t)frame_count;
}

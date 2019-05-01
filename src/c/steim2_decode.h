/*
 * steim2_decode.h: High-Throughput Steim-2 Seismic Decompression Engine
 *
 * Implements FDSN SEED Steim-2 difference compression decoding for
 * real-time MiniSEED seismic telemetry ingestion.
 */

#ifndef SCARP_STEIM2_DECODE_H
#define SCARP_STEIM2_DECODE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Decode a sequence of 64-byte Steim-2 frames into 32-bit integer sample values.
 * Returns the total number of decoded samples, or negative error code on failure.
 */
int32_t steim2_decode_frames(const uint8_t* frame_bytes, size_t num_frames,
                             int32_t* out_samples, size_t max_samples,
                             int32_t* out_last_sample);

/*
 * Compress an array of 32-bit samples into 64-byte Steim-2 frames.
 * Returns the number of frames written, or negative error code on failure.
 */
int32_t steim2_encode_frames(const int32_t* samples, size_t num_samples,
                             uint8_t* out_frame_bytes, size_t max_frames);

#ifdef __cplusplus
}
#endif

#endif /* SCARP_STEIM2_DECODE_H */

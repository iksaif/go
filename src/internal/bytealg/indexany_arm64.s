// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// IndexAny ARM64 NEON Optimized Implementation
//
// This file contains optimized NEON implementations with inline ASCII detection:
//
// 1. indexanyNeonUnrolled - For small charsets (≤5 bytes recommended)
//    - Uses unrolled NEON comparisons (VDUP+VCMEQ+VORR per charset byte)
//    - Detects non-ASCII while building charset vector
//    - Returns -2 if non-ASCII found (caller uses UTF-8 path)
//    - Otherwise returns position or -1
//
// 2. indexanyNeonLookup - For large charsets (>16 bytes)
//    - Builds 256-byte lookup table while detecting non-ASCII
//    - Returns -2 if non-ASCII found
//    - Uses unrolled scalar lookups (not NEON for search)
//
// Key innovation: ASCII detection happens DURING lookup structure build,
// not as a separate pass. This avoids scanning chars twice.

// func indexanyNeonUnrolled(s []byte, chars string) int
//
// NEON Unrolled implementation with inline ASCII detection
// For charsets ≤16 bytes (optimal for 2-5 bytes)
//
// Returns:
//   -2: Non-ASCII character found in chars (use UTF-8 path)
//   -1: No match found
//   ≥0: Position of first match
//
// Algorithm:
//   1. Build charset vector while checking ASCII (return -2 if non-ASCII)
//   2. Use NEON to load 16 bytes at a time
//   3. Compare each byte against charset using unrolled comparisons
//   4. Return first match position
//
TEXT ·indexanyASCIINeonUnrolled<ABIInternal>(SB), NOSPLIT, $32-48
	// Registers (ABIInternal calling convention):
	//   R0 = s.data
	//   R1 = s.len
	//   R2 = s.cap (unused)
	//   R3 = chars.data
	//   R4 = chars.len
	// Return:
	//   R0 = result
	//
	// Stack: 32 bytes for charset buffer (16 bytes aligned + padding)

	// Rearrange to match internal register usage
	MOVD	R3, R2                  // R2 = chars.data
	MOVD	R4, R3                  // R3 = chars.len

	// Check edge cases
	CBZ	R3, unrolled_not_found       // if len(chars) == 0
	CBZ	R1, unrolled_not_found       // if len(s) == 0

	// Check if charset is too large for unrolled implementation
	CMP	$16, R3
	BHI	unrolled_not_found           // if len(chars) > 16, return -1 (use lookup instead)

	// Build charset buffer while detecting non-ASCII
	// Store chars to stack, checking ASCII as we go
	MOVD	$0, R4                  // R4 = index into chars
	MOVD	$0x80, R5               // R5 = 128 (ASCII threshold)
	MOVD	RSP, R7                 // R7 = stack buffer pointer

unrolled_build_loop:
	MOVBU	(R2)(R4), R6            // R6 = chars[i]
	CMP	$128, R6
	BLO	unrolled_is_ascii            // if byte < 128, is ASCII
	B	unrolled_non_ascii
unrolled_is_ascii:

	// Store byte to stack buffer
	MOVB	R6, (R7)(R4)

	ADD	$1, R4
	CMP	R3, R4
	BLT	unrolled_build_loop

	// Zero-fill remaining bytes (for clean comparison)
	CMP	$16, R3
	BEQ	unrolled_build_done
	MOVD	$0, R6
unrolled_zero_loop:
	MOVB	R6, (R7)(R4)
	ADD	$1, R4
	CMP	$16, R4
	BLT	unrolled_zero_loop

unrolled_build_done:
	// Load charset from stack into V0
	VLD1	(R7), [V0.B16]

	// All chars are ASCII, proceed with NEON search
	// Check if buffer is too small for SIMD
	CMP	$16, R1
	BLO	unrolled_scalar              // if len(s) < 16, use scalar

	// Save original buffer pointer for index calculation
	MOVD	R0, R10                 // R10 = original s.data

unrolled_simd_loop:
	// Load 16 bytes from buffer
	VLD1	(R0), [V30.B16]         // V30 = s[0:15]

	// Initialize result accumulator
	VEOR	V29.B16, V29.B16, V29.B16  // V29 = 0

	// Unroll comparisons for each charset byte
	// We know R3 ≤ 16, so we can unroll

	// Compare byte 0
	VMOV	V0.B[0], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$1, R3
	BEQ	unrolled_check_match

	// Compare byte 1
	VMOV	V0.B[1], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$2, R3
	BEQ	unrolled_check_match

	// Compare byte 2
	VMOV	V0.B[2], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$3, R3
	BEQ	unrolled_check_match

	// Compare byte 3
	VMOV	V0.B[3], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$4, R3
	BEQ	unrolled_check_match

	// Compare byte 4
	VMOV	V0.B[4], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$5, R3
	BEQ	unrolled_check_match

	// Compare byte 5
	VMOV	V0.B[5], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$6, R3
	BEQ	unrolled_check_match

	// Compare byte 6
	VMOV	V0.B[6], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$7, R3
	BEQ	unrolled_check_match

	// Compare byte 7
	VMOV	V0.B[7], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$8, R3
	BEQ	unrolled_check_match

	// Compare byte 8
	VMOV	V0.B[8], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$9, R3
	BEQ	unrolled_check_match

	// Compare byte 9
	VMOV	V0.B[9], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$10, R3
	BEQ	unrolled_check_match

	// Compare byte 10
	VMOV	V0.B[10], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$11, R3
	BEQ	unrolled_check_match

	// Compare byte 11
	VMOV	V0.B[11], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$12, R3
	BEQ	unrolled_check_match

	// Compare byte 12
	VMOV	V0.B[12], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$13, R3
	BEQ	unrolled_check_match

	// Compare byte 13
	VMOV	V0.B[13], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$14, R3
	BEQ	unrolled_check_match

	// Compare byte 14
	VMOV	V0.B[14], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

	CMP	$15, R3
	BEQ	unrolled_check_match

	// Compare byte 15
	VMOV	V0.B[15], R6
	VDUP	R6, V28.B16
	VCMEQ	V30.B16, V28.B16, V28.B16
	VORR	V28.B16, V29.B16, V29.B16

unrolled_check_match:
	// Check if any match found in this 16-byte chunk
	VMOV	V29.D[0], R6
	VMOV	V29.D[1], R7
	ORR	R6, R7, R6
	CBNZ	R6, unrolled_found_in_chunk

	// No match, advance to next 16 bytes
	SUB	$16, R1, R1
	ADD	$16, R0, R0
	CMP	$16, R1
	BHS	unrolled_simd_loop           // if len >= 16, continue

	// Handle remaining bytes with scalar
	CBZ	R1, unrolled_not_found

unrolled_scalar:
	// Scalar search for remaining bytes
	MOVD	$0, R8                  // R8 = offset in current region

unrolled_scalar_outer:
	MOVBU	(R0)(R8), R6            // R6 = s[offset]

	// Check against all charset bytes
	MOVD	$0, R4                  // R4 = charset index

unrolled_scalar_inner:
	MOVBU	(R2)(R4), R7            // R7 = chars[i]
	CMP	R6, R7
	BEQ	unrolled_scalar_found

	ADD	$1, R4
	CMP	R3, R4
	BLT	unrolled_scalar_inner

	// No match, next byte
	ADD	$1, R8
	CMP	R1, R8
	BLT	unrolled_scalar_outer

	B	unrolled_not_found

unrolled_scalar_found:
	// Calculate position from start
	SUB	R10, R0, R0             // offset of current region
	ADD	R8, R0
	RET

unrolled_found_in_chunk:
	// Found match in 16-byte chunk, find exact position
	MOVD	$0, R8                  // R8 = offset in chunk (0-15)

unrolled_find_position:
	MOVBU	(R0)(R8), R6            // R6 = s[offset]

	// Check against charset
	MOVD	$0, R4

unrolled_check_byte:
	MOVBU	(R2)(R4), R7
	CMP	R6, R7
	BEQ	unrolled_found_exact

	ADD	$1, R4
	CMP	R3, R4
	BLT	unrolled_check_byte

	// This byte doesn't match, try next
	ADD	$1, R8
	CMP	$16, R8
	BLT	unrolled_find_position

	// Should never reach here
	B	unrolled_not_found

unrolled_found_exact:
	// Calculate absolute position
	SUB	R10, R0, R0
	ADD	R8, R0
	RET

unrolled_non_ascii:
	// Non-ASCII character detected in chars
	// Return -2 to signal caller to use UTF-8 path
	MOVD	$-2, R0
	RET

unrolled_not_found:
	MOVD	$-1, R0
	RET

// func indexanyNeonLookup(s []byte, chars string) int
//
// NEON Lookup implementation with inline ASCII detection
// For charsets >16 bytes
//
// Returns:
//   -2: Non-ASCII character found in chars
//   -1: No match found
//   ≥0: Position of first match
//
// Algorithm:
//   1. Build 256-byte lookup table while checking ASCII (return -2 if non-ASCII)
//   2. Use unrolled scalar lookups for search (optimized for ARM64 cache)
//   3. Return first match position
//
TEXT ·indexanyASCIINeonLookup<ABIInternal>(SB), NOSPLIT, $256-48
	// Registers (ABIInternal calling convention):
	//   R0 = s.data
	//   R1 = s.len
	//   R2 = s.cap (unused)
	//   R3 = chars.data
	//   R4 = chars.len
	// Return:
	//   R0 = result
	//
	// Stack frame: 256 bytes for lookup table

	// Rearrange to match internal register usage
	MOVD	R3, R2                  // R2 = chars.data
	MOVD	R4, R3                  // R3 = chars.len

	// Check edge cases
	CBZ	R3, lookup_not_found
	CBZ	R1, lookup_not_found

	// Initialize 256-byte lookup table on stack
	// SP points to our 256-byte buffer
	MOVD	$0, R4                  // Clear counter
	MOVD	$256, R5                // Table size

lookup_clear_table:
	MOVB	ZR, (RSP)(R4)
	ADD	$1, R4
	CMP	R5, R4
	BLT	lookup_clear_table

	// Build lookup table while detecting non-ASCII
	MOVD	$0, R4                  // R4 = index into chars
	MOVD	$0x80, R5               // R5 = 128 (ASCII threshold)
	MOVD	$1, R7                  // R7 = 1 (mark value)

lookup_build_loop:
	MOVBU	(R2)(R4), R6            // R6 = chars[i]
	CMP	R5, R6
	BHS	lookup_non_ascii        // if byte >= 128, non-ASCII

	// Mark this byte in lookup table
	MOVB	R7, (RSP)(R6)           // table[chars[i]] = 1

	ADD	$1, R4
	CMP	R3, R4
	BLT	lookup_build_loop

	// All chars are ASCII, proceed with optimized scalar search
	// For 256-byte lookup tables, scalar code with good cache locality
	// is already very efficient on ARM64

	// Save original buffer pointer
	MOVD	R0, R10

	// Process in 4-byte chunks for better throughput
	CMP	$4, R1
	BLO	lookup_scalar

lookup_unrolled_loop:
	// Check 4 bytes in parallel (unrolled)
	MOVBU	0(R0), R6
	MOVBU	(RSP)(R6), R7
	CBNZ	R7, lookup_found_offset0

	MOVBU	1(R0), R6
	MOVBU	(RSP)(R6), R7
	CBNZ	R7, lookup_found_offset1

	MOVBU	2(R0), R6
	MOVBU	(RSP)(R6), R7
	CBNZ	R7, lookup_found_offset2

	MOVBU	3(R0), R6
	MOVBU	(RSP)(R6), R7
	CBNZ	R7, lookup_found_offset3

	// Advance by 4 bytes
	ADD	$4, R0
	SUB	$4, R1
	CMP	$4, R1
	BHS	lookup_unrolled_loop

	// Handle remaining bytes
	CBZ	R1, lookup_not_found

lookup_scalar:
	// Scalar search for remaining bytes
	MOVD	$0, R8

lookup_scalar_loop:
	MOVBU	(R0)(R8), R6
	MOVBU	(RSP)(R6), R7
	CBNZ	R7, lookup_scalar_found

	ADD	$1, R8
	CMP	R1, R8
	BLT	lookup_scalar_loop

	B	lookup_not_found

lookup_found_offset0:
	// Found at offset 0 in current chunk
	SUB	R10, R0, R0
	RET

lookup_found_offset1:
	// Found at offset 1 in current chunk
	SUB	R10, R0, R0
	ADD	$1, R0
	RET

lookup_found_offset2:
	// Found at offset 2 in current chunk
	SUB	R10, R0, R0
	ADD	$2, R0
	RET

lookup_found_offset3:
	// Found at offset 3 in current chunk
	SUB	R10, R0, R0
	ADD	$3, R0
	RET

lookup_scalar_found:
	SUB	R10, R0, R0
	ADD	R8, R0
	RET

lookup_non_ascii:
	// Non-ASCII detected
	MOVD	$-2, R0
	RET

lookup_not_found:
	MOVD	$-1, R0
	RET
// TBL-based IndexAny implementation for Go with SIMD support
// Uses split bitvector approach with NEON acceleration

TEXT ·indexanyASCIINeonTBL<ABIInternal>(SB), NOSPLIT, $48-48
	// Input registers (ABIInternal):
	// R0 = s.data
	// R1 = s.len
	// R2 = s.cap (unused)
	// R3 = chars.data
	// R4 = chars.len

	// Rearrange to match internal register usage
	MOVD	R3, R2                       // R2 = chars.data
	MOVD	R4, R3                       // R3 = chars.len

	// Edge cases
	CBZ	R3, tbl_not_found            // if len(chars) == 0
	CBZ	R1, tbl_not_found            // if len(s) == 0
	CMP	$16, R3
	BHI	tbl_not_found                // if len(chars) > 16

	// Stack layout: 0..15 = bitvec_low, 16..31 = bitvec_high, 32..47 = bit_masks
	// Clear bitvec_low and bitvec_high
	MOVD	$0, R4
tbl_clear_loop:
	MOVB	ZR, (RSP)(R4)                // bitvec_low[R4] = 0
	ADD	$16, RSP, R5
	MOVB	ZR, (R5)(R4)                 // bitvec_high[R4] = 0
	ADD	$1, R4
	CMP	$16, R4
	BLT	tbl_clear_loop

	// Build bitvectors
	MOVD	$0, R4                       // i = 0

tbl_build_loop:
	CMP	R4, R3
	BEQ	tbl_build_done

	MOVBU	(R2)(R4), R5                 // c = chars[i]
	CMP	$128, R5
	BHS	tbl_non_ascii                // if c >= 128

	LSR	$4, R5, R6                   // high = c >> 4
	AND	$0xF, R5, R7                 // low = c & 0xF

	// Compute bit mask: 1 << bit_pos
	MOVD	$1, R8
	CMP	$8, R7
	BGE	tbl_set_high_bit

tbl_set_low_bit:
	// low < 8: bitvec_low[high] |= (1 << low)
	LSL	R7, R8, R8                   // mask = 1 << low
	MOVBU	(RSP)(R6), R9                // load bitvec_low[high]
	ORR	R8, R9, R9                   // OR with mask
	MOVB	R9, (RSP)(R6)                // store back
	B	tbl_build_next

tbl_set_high_bit:
	// low >= 8: bitvec_high[high] |= (1 << (low - 8))
	SUB	$8, R7, R11                  // bit_pos = low - 8
	LSL	R11, R8, R8                  // mask = 1 << bit_pos
	ADD	$16, RSP, R12
	MOVBU	(R12)(R6), R9                // load bitvec_high[high]
	ORR	R8, R9, R9                   // OR with mask
	MOVB	R9, (R12)(R6)                // store back

tbl_build_next:
	ADD	$1, R4
	B	tbl_build_loop

tbl_build_done:
	// Load bitvectors into NEON registers
	MOVD	RSP, R4
	VLD1	(R4), [V0.B16]               // V0 = bitvec_low
	ADD	$16, RSP, R5
	VLD1	(R5), [V1.B16]               // V1 = bitvec_high

	// Build bit mask lookup table at sp+32
	ADD	$32, RSP, R4
	MOVD	$1, R5
	MOVB	R5, (R4)                     // masks[0] = 1
	LSL	$1, R5, R5
	MOVB	R5, 1(R4)                    // masks[1] = 2
	LSL	$1, R5, R5
	MOVB	R5, 2(R4)                    // masks[2] = 4
	LSL	$1, R5, R5
	MOVB	R5, 3(R4)                    // masks[3] = 8
	LSL	$1, R5, R5
	MOVB	R5, 4(R4)                    // masks[4] = 16
	LSL	$1, R5, R5
	MOVB	R5, 5(R4)                    // masks[5] = 32
	LSL	$1, R5, R5
	MOVB	R5, 6(R4)                    // masks[6] = 64
	LSL	$1, R5, R5
	MOVB	R5, 7(R4)                    // masks[7] = 128
	VLD1	(R4), [V2.B16]               // V2 = bit masks

	// Load NEON constants
	VMOVI	$0x0F, V3.B16                // V3 = 0x0F (for low nibble mask)
	VMOVI	$0x07, V4.B16                // V4 = 0x07 (for low 3 bits)

	// Save original pointer
	MOVD	R0, R13

	// SIMD loop: process 16 bytes at a time
tbl_simd_loop:
	CMP	$16, R1
	BLO	tbl_scalar_start                 // if len < 16, go to scalar

	// Load 16 input bytes
	VLD1.P	16(R0), [V6.B16]

	// Extract high nibbles (shift right by 4)
	VUSHR	$4, V6.B16, V7.B16

	// Extract low nibbles (mask with 0x0F)
	VAND	V3.B16, V6.B16, V8.B16

	// Extract low 3 bits of low nibbles (for bit position within byte)
	VAND	V4.B16, V8.B16, V9.B16

	// TBL lookups:
	// 1. Look up bitvector bytes using high nibbles as indices
	VTBL	V7.B16, [V0.B16], V10.B16    // V10 = bitvec_low[high_nibble]
	VTBL	V7.B16, [V1.B16], V11.B16    // V11 = bitvec_high[high_nibble]

	// 2. Look up bit masks using low 3 bits as indices
	VTBL	V9.B16, [V2.B16], V12.B16    // V12 = mask[low_nibble & 7]

	// Test bits in both bitvectors
	VAND	V12.B16, V10.B16, V13.B16    // V13 = bitvec_low & mask
	VAND	V12.B16, V11.B16, V14.B16    // V14 = bitvec_high & mask

	// Select correct result based on whether low_nibble >= 8
	// VMOVI loads 8 into V15, then VCMGE compares
	VMOVI	$8, V15.B16
	VCMGE	V15.B16, V8.B16, V15.B16    // V15 = (V8 >= V15) = (low_nibbles >= 8)

	// Use VBSL: result = (mask & true_val) | (~mask & false_val)
	// VBSL Vm, Vn, Vd encodes as: Vd = (Vd & Vn) | (~Vd & Vm)
	// We want: V15 = (V15 & V14) | (~V15 & V13) = (select_mask & result_high) | (~select_mask & result_low)
	VBSL	V13.B16, V14.B16, V15.B16

	// Check if any byte in V15 is non-zero
	VUMAXV	V15.B16, V16
	VMOV	V16.B[0], R6
	CBNZ	R6, tbl_found_in_chunk       // If non-zero, found a match

	// Continue to next chunk
	SUB	$16, R1
	CMP	$16, R1
	BHS	tbl_simd_loop                    // if len >= 16, continue SIMD loop

tbl_scalar_start:
	// Scalar search loop
	MOVD	$0, R4                       // index = 0

tbl_scalar_loop:
	CMP	R4, R1
	BEQ	tbl_not_found

	MOVBU	(R0)(R4), R5                 // c = src[index]
	CMP	$128, R5
	BHS	tbl_not_found                // if c >= 128

	LSR	$4, R5, R6                   // high = c >> 4
	AND	$0xF, R5, R7                 // low = c & 0xF

	// Compute bit position and select bitvector
	CMP	$8, R7
	BGE	tbl_test_high_bit

tbl_test_low_bit:
	// low < 8: check bitvec_low[high]
	MOVBU	(RSP)(R6), R8                // bitvec_byte = bitvec_low[high]
	MOVD	$1, R9
	LSL	R7, R9, R9                   // mask = 1 << low
	TST	R8, R9
	BNE	tbl_scalar_found
	B	tbl_scalar_next

tbl_test_high_bit:
	// low >= 8: check bitvec_high[high]
	ADD	$16, RSP, R11
	MOVBU	(R11)(R6), R8                // bitvec_byte = bitvec_high[high]
	SUB	$8, R7, R12                  // bit_pos = low - 8
	MOVD	$1, R9
	LSL	R12, R9, R9                  // mask = 1 << bit_pos
	TST	R8, R9
	BNE	tbl_scalar_found

tbl_scalar_next:
	ADD	$1, R4
	B	tbl_scalar_loop

tbl_found_in_chunk:
	// Found match in 16-byte chunk, find exact position
	// Go back 16 bytes
	SUB	$16, R0

	// Scan the 16 bytes to find exact match
	MOVD	$0, R4
tbl_find_exact:
	MOVBU	(R0)(R4), R5                 // c = src[index]
	LSR	$4, R5, R6                   // high = c >> 4
	AND	$0xF, R5, R7                 // low = c & 0xF

	CMP	$8, R7
	BGE	tbl_check_high_exact

tbl_check_low_exact:
	MOVBU	(RSP)(R6), R8
	MOVD	$1, R9
	LSL	R7, R9, R9
	TST	R8, R9
	BNE	tbl_found_exact
	B	tbl_find_exact_next

tbl_check_high_exact:
	ADD	$16, RSP, R11
	MOVBU	(R11)(R6), R8
	SUB	$8, R7, R12
	MOVD	$1, R9
	LSL	R12, R9, R9
	TST	R8, R9
	BNE	tbl_found_exact

tbl_find_exact_next:
	ADD	$1, R4
	CMP	$16, R4
	BLT	tbl_find_exact

	// Should never reach here if umaxv was non-zero
	B	tbl_not_found

tbl_found_exact:
	// Calculate final index
	SUB	R13, R0, R0                  // offset from original start
	ADD	R4, R0                       // add position within chunk
	RET

tbl_scalar_found:
	// Calculate absolute index: (current_ptr - original_ptr) + relative_index
	SUB	R13, R0, R0                  // R0 = bytes processed by SIMD
	ADD	R4, R0                       // R0 = total index
	RET

tbl_non_ascii:
	MOVD	$-2, R0
	RET

tbl_not_found:
	MOVD	$-1, R0
	RET

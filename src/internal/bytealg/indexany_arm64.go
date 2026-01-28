// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package bytealg

// IndexAnyASCII returns the index of the first occurrence of any byte in chars
// within s, or -1 if not found, or -2 if non-ASCII is detected in chars.
// ASCII detection happens during lookup structure build (single pass).
// This implementation uses an adaptive strategy optimized for ARM64 NEON.
func IndexAnyASCII(s []byte, chars string) int {
	if len(chars) == 0 || len(s) == 0 {
		return -1
	}

	// Adaptive strategy based on charset size
	// Benchmarking shows optimal approaches for different charset sizes:
	//
	// Small/Medium charsets (≤16 bytes): TBL with split bitvector is fastest
	//   - 1-byte: 13714 MB/s (2.3x faster than NEON unrolled)
	//   - 4-byte: 13186 MB/s (4.6x faster than NEON unrolled)
	//   - 8-byte: 12753 MB/s (4.5x faster than scalar lookup)
	//   - 16-byte: 11848 MB/s (4.2x faster than scalar lookup)
	//
	// Large charsets (>16 bytes): NEON 256-byte lookup table
	//   - 17-32 bytes: ~3000-4000 MB/s
	//   - 62+ bytes: up to 33715 MB/s

	if len(chars) <= 16 {
		// Use TBL (Table Lookup) with split bitvector approach
		// Fastest for all charset sizes ≤16 bytes
		return indexanyASCIINeonTBL(s, chars)
	} else {
		// Large charset: Use NEON 256-byte lookup table
		return indexanyASCIINeonLookup(s, chars)
	}
}

// indexanyASCIINeonUnrolled is implemented in indexany_arm64.s
// Uses unrolled NEON comparisons for small charsets (≤5 bytes)
//
//go:noescape
func indexanyASCIINeonUnrolled(s []byte, chars string) int

// indexanyASCIINeonLookup is implemented in indexany_arm64.s
// Uses 256-byte lookup table for large charsets (>16 bytes)
//
//go:noescape
func indexanyASCIINeonLookup(s []byte, chars string) int

// indexanyASCIINeonTBL is implemented in indexany_arm64.s
// Uses NEON TBL instruction with split bitvector for charsets ≤16 bytes
//
//go:noescape
func indexanyASCIINeonTBL(s []byte, chars string) int

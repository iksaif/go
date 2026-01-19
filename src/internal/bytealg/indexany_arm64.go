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
	// Testing shows different optimal approaches for different charset sizes:
	//
	// Small charsets (2-5 bytes): NEON unrolled comparisons excel
	// Medium charsets (6-16 bytes): Scalar lookup is faster than NEON
	// Large charsets (17+ bytes): NEON lookup table approach

	if len(chars) <= 5 {
		// Small charset: Use NEON unrolled comparisons
		// Best for 2-5 byte charsets
		return indexanyNeonUnrolled(s, chars)
	} else if len(chars) <= 16 {
		// Medium charset: Scalar lookup is faster than NEON unrolled
		return indexanyScalarLookup(s, chars)
	} else {
		// Large charset: Use NEON lookup table approach
		return indexanyNeonLookup(s, chars)
	}
}

// indexanyNeonUnrolled is implemented in indexany_arm64.s
// Uses unrolled NEON comparisons for small charsets (≤5 bytes)
//
//go:noescape
func indexanyNeonUnrolled(s []byte, chars string) int

// indexanyNeonLookup is implemented in indexany_arm64.s
// Uses 256-byte lookup table for large charsets (>16 bytes)
//
//go:noescape
func indexanyNeonLookup(s []byte, chars string) int

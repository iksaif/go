// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bytealg

// indexanyASCIILookup uses a 256-byte lookup table to find the first occurrence
// of any byte in chars within s.
// Returns -1 if not found, or -2 if non-ASCII is detected in chars.
// ASCII detection happens during table build (single pass).
//
// A byte array table is used instead of a bit vector (32 bytes) because:
// - Direct lookup (table[b]) vs bit vector requiring shift and mask operations
// - Better performance for medium-sized charsets: lookup outperforms bit vector for charsets ≥4 bytes and always wins for charsets ≥8 bytes
// - The 256-byte footprint still fits in L1 cache alongside the input buffer
// Note: 256 entries (not 128) because the search buffer s can contain any byte values, though only ASCII chars are accepted
func indexanyASCIILookup(s []byte, chars string) int {
	// Build lookup table while checking for ASCII
	var table [256]byte
	for _, b := range []byte(chars) {
		if b >= 0x80 {
			return -2 // Non-ASCII detected
		}
		table[b] = 1
	}

	// Search using table
	for i, c := range s {
		if table[c] != 0 {
			return i
		}
	}
	return -1
}

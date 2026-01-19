// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bytealg

// indexanyScalarLookup uses a 256-byte lookup table to find the first occurrence
// of any byte in chars within s.
// Returns -1 if not found, or -2 if non-ASCII is detected in chars.
// ASCII detection happens during table build (single pass).
func indexanyScalarLookup(s []byte, chars string) int {
	// Build lookup table while checking for ASCII
	var table [256]byte
	for i := 0; i < len(chars); i++ {
		c := chars[i]
		if c >= 0x80 {
			return -2 // Non-ASCII detected
		}
		table[c] = 1
	}

	// Search using table
	for i, c := range s {
		if table[c] != 0 {
			return i
		}
	}
	return -1
}

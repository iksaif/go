// Copyright 2026 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !arm64

package bytealg

// IndexAnyASCII returns the index of the first occurrence of any byte in chars
// within s, or -1 if not found, or -2 if non-ASCII is detected in chars.
// ASCII detection happens during lookup structure build (single pass).
// This is a generic implementation using a lookup table.
func IndexAnyASCII(s []byte, chars string) int {
	if len(chars) == 0 || len(s) == 0 {
		return -1
	}

	// For very small charsets, use simple nested loop
	if len(chars) <= 4 {
		// Check for ASCII first
		for j := 0; j < len(chars); j++ {
			if chars[j] >= 0x80 {
				return -2 // Non-ASCII detected
			}
		}
		// Search
		for i, c := range s {
			for j := 0; j < len(chars); j++ {
				if c == chars[j] {
					return i
				}
			}
		}
		return -1
	}

	// For larger charsets, use shared lookup table implementation
	return indexanyASCIILookup(s, chars)
}

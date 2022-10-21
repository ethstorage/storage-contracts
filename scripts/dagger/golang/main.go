package main

import (
	"crypto/sha512"
	"fmt"
)

func selfCheck() {
	cache := make([]uint32, 1024/4)
	generateCache(cache, 0, []byte("123"), makeHasher(sha512.New()))
	// item := generateDatasetItem(cache, 123, makeHasher(sha3.NewLegacyKeccak512()))
	item := generateDatasetItem(cache, 123, makeHasher(sha512.New()))
	fmt.Printf("item %x\n", item)
	// mask := generateMaskItem(cache, 123, makeHasher(sha3.NewLegacyKeccak512()), item)
	mask := generateMaskItem(cache, 123, makeHasher(sha512.New()), item)
	fmt.Printf("mask %x\n", mask)

	// Create a hasher to reuse between invocations
	hasher := makeHasher(sha512.New())
	initHash := make([]byte, 64)
	hasher(initHash, []byte("123"))
	lookupCache := make([][]uint32, len(cache)/16)
	for i := 0; i < len(cache)/16; i++ {
		lookupCache[i] = make([]uint32, 64/4)
		for j := 0; j < 64/4; j++ {
			lookupCache[i][j] = cache[i*16+j]
		}
	}
	fmt.Printf("initHash %x\n", initHash)
	hashimotoMask, _ := hashimotoEx(initHash, uint64(4*len(cache)), func(index uint32) []uint32 { return lookupCache[index] })
	fmt.Printf("hashimotoMask %x\n", hashimotoMask)
}

func main() {
	selfCheck()
}

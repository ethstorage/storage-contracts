package main

import (
	"fmt"

	"golang.org/x/crypto/sha3"
)

func selfCheck() {
	cache := make([]uint32, 1024/4)
	generateCache(cache, 0, []byte("123"))
	item := generateDatasetItem(cache, 123, makeHasher(sha3.NewLegacyKeccak512()))
	fmt.Printf("item %x\n", item)
	mask := generateMaskItem(cache, 123, makeHasher(sha3.NewLegacyKeccak512()), item)
	fmt.Printf("mask %x\n", mask)
}

func main() {
	selfCheck()
}

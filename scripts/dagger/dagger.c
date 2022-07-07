#include <stdio.h>

#include "sha512.c"

#define HASH_BYTES 64
#define WORD_BYTES 8
#define CACHE_ROUND 3
#define CACHE_ITEM(cache, idx) ((cache) + (idx) * HASH_BYTES)

unsigned char *generate_cache(uint64_t cache_size, unsigned char *seed, uint64_t seed_size) {
    unsigned char *cache = malloc(cache_size);
    if (cache == NULL) {
        return (NULL);
    }
    unsigned char *hash = malloc(HASH_BYTES);
    if (hash == NULL) {
        free(hash);
        return (NULL);
    }

    SHA512(seed, seed_size, cache);
    uint64_t rows = cache_size / HASH_BYTES;
    for (int i = 1; i < rows; i++) {
        SHA512(CACHE_ITEM(cache, i - 1), HASH_BYTES, CACHE_ITEM(cache, i));
    }
    for (uint64_t r = 0; r < CACHE_ROUND; r++) {
        for (uint64_t i = 0; i < rows; i++) {
            // TODO: big order casting
            uint32_t v = *((uint32_t *)(CACHE_ITEM(cache, i))) % rows;
            unsigned char *p0 = CACHE_ITEM(cache, v);
            unsigned char *p1 = CACHE_ITEM(cache, (i - 1 + rows) % rows);
            for (int k = 0; k < HASH_BYTES; k++) {
                hash[k] = p0[k] ^ p1[k];
            }
            SHA512(hash, HASH_BYTES, CACHE_ITEM(cache, i));
        }
    }
    free(hash);
    return (cache);
}

int main(int argc, char *argv[]) {
    unsigned char *digest = malloc(64);
    SHA512(0, 0, digest);
    for (int i = 0; i < 64; i++) {
        printf("%x", digest[i]);
    }
    printf("\n");

    unsigned char seed[] = "123";

    unsigned char *cache = generate_cache(1024, seed, sizeof(seed) - 1);
    uint64_t *cache_u64 = (uint64_t *)cache;
    
    for (int i = 0; i < 1024 / WORD_BYTES; i++) {
        printf("%llu ", cache_u64[i]);
    }
    printf("\n");

    return (0);
}



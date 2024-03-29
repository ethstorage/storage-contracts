#include <stdio.h>
#include <time.h>

#include "sha512.c"

#define HASH_BYTES 64
#define WORD_BYTES 8
#define WORDS_PER_HASH 8
#define CACHE_ROUND 3
#define CACHE_ITEM(cache, idx) ((cache) + (idx) * HASH_BYTES)
#define DATASET_PARENTS 256

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

__attribute__((always_inline))
uint64_t fnv64(uint64_t a, uint64_t b) {
    return ((a * 0x00000100000001B3)) ^ b;
}

void calculate_dataset_item(unsigned char *cache, uint64_t cache_size, uint64_t i, unsigned char* dataset) {
    uint64_t rows = cache_size / HASH_BYTES;

    uint64_t *cache_u64 = (uint64_t *)cache;
    uint64_t *mix = (uint64_t *)dataset;
    mix[0] = cache_u64[(i % rows) * WORDS_PER_HASH] ^ i;
    for (uint64_t j = 1; j < WORDS_PER_HASH; j++) {
        mix[j] = cache_u64[(i % rows) * WORDS_PER_HASH + j];
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);

    for (uint64_t j = 0; j < DATASET_PARENTS; j++) {
        uint64_t cache_idx = fnv64(i ^ j, mix[j % WORDS_PER_HASH]) % rows;
        for (uint64_t k = 0; k < WORDS_PER_HASH; k++) {
            mix[k] = fnv64(mix[k], cache_u64[cache_idx * WORDS_PER_HASH + k]);
        }
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);
    return;
}

void calculate_dataset_item_opt(unsigned char *cache, uint64_t cache_size, uint64_t i, unsigned char* dataset) {
    uint64_t rows = cache_size / HASH_BYTES;

    uint64_t *cache_u64 = (uint64_t *)cache;
    uint64_t *mix = (uint64_t *)dataset;
    mix[0] = cache_u64[(i % rows) * WORDS_PER_HASH] ^ i;
    for (uint64_t j = 1; j < WORDS_PER_HASH; j++) {
        mix[j] = cache_u64[(i % rows) * WORDS_PER_HASH + j];
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);

    for (uint64_t j = 0; j < DATASET_PARENTS; j++) {
        uint64_t cache_idx = fnv64(i ^ j, mix[j % WORDS_PER_HASH]) % rows;
        uint64_t *cache_u64_ptr = &cache_u64[cache_idx * WORDS_PER_HASH];
        mix[0] = fnv64(mix[0], cache_u64_ptr[0]);
        mix[1] = fnv64(mix[1], cache_u64_ptr[1]);
        mix[2] = fnv64(mix[2], cache_u64_ptr[2]);
        mix[3] = fnv64(mix[3], cache_u64_ptr[3]);
        mix[4] = fnv64(mix[4], cache_u64_ptr[4]);
        mix[5] = fnv64(mix[5], cache_u64_ptr[5]);
        mix[6] = fnv64(mix[6], cache_u64_ptr[6]);
        mix[7] = fnv64(mix[7], cache_u64_ptr[7]);
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);
    return;
}

void simple_verify() {
    unsigned char seed[] = "123";

    unsigned char *cache = generate_cache(1024, seed, sizeof(seed) - 1);

    uint64_t *cache_u64 = (uint64_t *)cache;
    for (int i = 0; i < 1024 / WORD_BYTES; i++) {
        printf("%llu ", cache_u64[i]);
    }
    printf("\n");

    unsigned char *data = malloc(HASH_BYTES);

    calculate_dataset_item(cache, 1024, 123, data);
    for (int i = 0; i < 64; i++) {
        printf("%x", data[i]);
    }
    printf("\n");

    return;
}

void self_verify() {
    unsigned char seed[] = "123";

    unsigned char *cache = generate_cache(1024, seed, sizeof(seed) - 1);

    unsigned char *data0 = malloc(HASH_BYTES);
    unsigned char *data1 = malloc(HASH_BYTES);

    calculate_dataset_item(cache, 1024, 123, data0);
    calculate_dataset_item_opt(cache, 1024, 123, data1);
    for (int i = 0; i < 64; i++) {
        if (data0[i] != data1[i]) {
            free(data0);
            free(data1);
            printf("self_verify() failed!\n");
            return;
        }
    }

    free(data0);
    free(data1);

    printf("self_verify() passed\n");
    return;
}

void hash_empty_verify() {
    unsigned char *digest = malloc(64);
    SHA512(0, 0, digest);
    for (int i = 0; i < 64; i++) {
        printf("%x", digest[i]);
    }
    printf("\n");
}

void benchmark() {
    unsigned char seed[] = "123";
    struct timespec start, end;
    struct timespec startb, endb;

    uint64_t cache_size = 83886080; // 80 MB
    printf("Generating cache with size %llu\n", cache_size);
    clock_gettime(CLOCK_MONOTONIC, &start);
    unsigned char *cache = generate_cache(cache_size, seed, sizeof(seed) - 1);
    clock_gettime(CLOCK_MONOTONIC, &end);
    printf("Done! Took %0.2fs\n", (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9);

    clock_gettime(CLOCK_MONOTONIC, &start);
    clock_gettime(CLOCK_MONOTONIC, &startb);
    unsigned char *data = malloc(HASH_BYTES);
    uint64_t items = 10000000;
    for (uint64_t idx = 0; idx < items; idx ++) {
        calculate_dataset_item_opt(cache, cache_size, idx, data);

        if (idx % 10000 != 0) {
            continue;
        }

        clock_gettime(CLOCK_MONOTONIC, &endb);
        double used_time = (endb.tv_sec - startb.tv_sec) + (endb.tv_nsec - startb.tv_nsec) / 1e9;
        startb = endb;

        printf("rate %0.2f H/s, item %llu, ", 10000 / used_time, idx);
        for (int i = 0; i < 64; i++) {
            printf("%x", data[i]);
        }
        printf("\n");
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double used_time = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("Hash done! Took %0.2fs, rate %0.2f H/s\n", used_time, items / used_time);

    return;
}

int main(int argc, char *argv[]) {
    self_verify();
    benchmark();
    return (0);
}



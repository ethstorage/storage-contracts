#include <stdio.h>
#include <time.h>

#include <immintrin.h>

#include "sha512.c"

#define HASH_BYTES 64
#define WORD_BYTES 4
#define WORDS_PER_HASH 16
#define CACHE_ROUND 3
#define CACHE_ITEM(cache, idx) ((cache) + (idx) * HASH_BYTES)
#define DATASET_PARENTS 256
#define LOOP_ACCESSES 64
#define MIX_BYTES 128

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
uint64_t fnv32(uint32_t a, uint32_t b) {
    return ((a * 0x01000193)) ^ b;
}

void calculate_dataset_item(unsigned char *cache, uint64_t cache_size, uint64_t i, unsigned char* dataset) {
    uint64_t rows = cache_size / HASH_BYTES;

    uint32_t *cache_u32 = (uint32_t *)cache;
    uint32_t *mix = (uint32_t *)dataset;
    mix[0] = cache_u32[(i % rows) * WORDS_PER_HASH] ^ i;
    for (uint64_t j = 1; j < WORDS_PER_HASH; j++) {
        mix[j] = cache_u32[(i % rows) * WORDS_PER_HASH + j];
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);

    for (uint64_t j = 0; j < DATASET_PARENTS; j++) {
        uint64_t cache_idx = fnv32(i ^ j, mix[j % WORDS_PER_HASH]) % rows;
        for (uint64_t k = 0; k < WORDS_PER_HASH; k++) {
            mix[k] = fnv32(mix[k], cache_u32[cache_idx * WORDS_PER_HASH + k]);
        }
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);
    return;
}

void calculate_dataset_item_opt(unsigned char *cache, uint64_t cache_size, uint64_t i, unsigned char* dataset) {
    uint32_t rows = cache_size / HASH_BYTES;

    uint32_t *cache_u32 = (uint32_t *)cache;
    uint32_t *mix = (uint32_t *)dataset;
    mix[0] = cache_u32[(i % rows) * WORDS_PER_HASH] ^ i;
    for (uint64_t j = 1; j < WORDS_PER_HASH; j++) {
        mix[j] = cache_u32[(i % rows) * WORDS_PER_HASH + j];
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);

    for (uint32_t j = 0; j < DATASET_PARENTS; j++) {
        uint32_t cache_idx = fnv32(i ^ j, mix[j % WORDS_PER_HASH]) % rows;
        uint32_t *cache_u32_ptr = &cache_u32[cache_idx * WORDS_PER_HASH];
        for (uint64_t k = 0; k < WORDS_PER_HASH; k++) {
            mix[k] = fnv32(mix[k], cache_u32_ptr[k]);
        }
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);
    return;
}

void calculate_mask_data(unsigned char *cache, uint64_t cache_size, uint64_t i, unsigned char* dataset) {
    uint32_t rows = cache_size / HASH_BYTES;

    uint32_t *cache_u32 = (uint32_t *)cache;
    uint32_t *mix = (uint32_t *)dataset;
    mix[0] = mix[0] ^ cache_u32[(i % rows) * WORDS_PER_HASH] ^ i;
    for (uint64_t j = 1; j < WORDS_PER_HASH; j++) {
        mix[j] = mix[j] ^ cache_u32[(i % rows) * WORDS_PER_HASH + j];
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);

    for (uint32_t j = 0; j < DATASET_PARENTS; j++) {
        uint32_t cache_idx = fnv32(i ^ j, mix[j % WORDS_PER_HASH]) % rows;
        uint32_t *cache_u32_ptr = &cache_u32[cache_idx * WORDS_PER_HASH];
        for (uint64_t k = 0; k < WORDS_PER_HASH; k++) {
            mix[k] = fnv32(mix[k], cache_u32_ptr[k]);
        }
    }

    // TODO: big order casting
    SHA512(dataset, HASH_BYTES, dataset);
    return;
}

void hashimoto(unsigned char* hash, uint64_t size, unsigned char* dataset, uint32_t* mix) {
    uint32_t *dataset_u32 = (uint32_t *)dataset;
    uint32_t *hash_u32 = (uint32_t *)hash;

    // replicate hash
    for (uint64_t i = 0; i < HASH_BYTES / 4; i++) {
        mix[i] = hash_u32[i];
        mix[i + HASH_BYTES / 4] = hash_u32[i];
    }

    uint32_t seedHead = mix[0];
    uint32_t mix_len = MIX_BYTES / 4;
    uint32_t rows = size / MIX_BYTES;

    // Mix in random dataset nodes
	for (uint32_t i = 0; i < LOOP_ACCESSES; i++) {
		uint64_t parent = fnv32(i^seedHead, mix[i%mix_len]) % rows;
        for (uint32_t j = 0; j < mix_len; j ++) {
            mix[j] = fnv32(mix[j], dataset_u32[parent * mix_len + j]);
        }
	}

    for (uint32_t i = 0; i < mix_len; i += 4) {
        mix[i / 4] = fnv32(fnv32(fnv32(mix[i], mix[i+1]), mix[i+2]), mix[i+3]);
    }

    return;
}

void hashimoto_avx(unsigned char* hash, uint64_t size, unsigned char* dataset, uint32_t* mix) {
    uint32_t *dataset_u32 = (uint32_t *)dataset;
    uint32_t *hash_u32 = (uint32_t *)hash;

    // replicate hash
    for (uint64_t i = 0; i < HASH_BYTES / 4; i++) {
        mix[i] = hash_u32[i];
        mix[i + HASH_BYTES / 4] = hash_u32[i];
    }

    __m256i m = _mm256_set1_epi32(0x01000193);
    __m256i mix0 = _mm256_load_si256(mix);
    __m256i mix1 = _mm256_load_si256(mix+8);
    __m256i mix2 = _mm256_load_si256(mix+16);
    __m256i mix3 = _mm256_load_si256(mix+24);

    unsigned char *mix_bytes0 = mix;
    unsigned char *mix_bytes1 = mix+8;
    unsigned char *mix_bytes2 = mix+16;
    unsigned char *mix_bytes3 = mix+24;

    uint32_t seedHead = mix[0];
    uint32_t mix_len = MIX_BYTES / 4;
    uint32_t rows = size / MIX_BYTES;

    // Mix in random dataset nodes
	for (uint32_t i = 0; i < LOOP_ACCESSES; i++) {
        uint32_t p = i % 32;
        if (p < 8) {
            _mm256_store_si256(mix_bytes0, mix0);
        } else if (p < 16) {
            _mm256_store_si256(mix_bytes1, mix1);
        } else if (p < 24) {
            _mm256_store_si256(mix_bytes2, mix2);
        } else {
            _mm256_store_si256(mix_bytes3, mix3);
        }

        uint64_t parent = fnv32(i^seedHead, mix[i%mix_len]) % rows;
        uint32_t *dataset_u32_ptr = &dataset_u32[parent * mix_len];
        // printf("%u\n", dataset_u32_ptr[0]);
        unsigned char *dataset_bytes = dataset_u32_ptr;
        __m256i c0 = _mm256_load_si256(dataset_bytes);
        __m256i c1 = _mm256_load_si256(dataset_bytes+32);
        __m256i c2 = _mm256_load_si256(dataset_bytes+64);
        __m256i c3 = _mm256_load_si256(dataset_bytes+96);

        mix0 = _mm256_mullo_epi32(mix0, m);
        mix0 = _mm256_xor_si256(mix0, c0);

        mix1 = _mm256_mullo_epi32(mix1, m);
        mix1 = _mm256_xor_si256(mix1, c1);

        mix2 = _mm256_mullo_epi32(mix2, m);
        mix2 = _mm256_xor_si256(mix2, c2);

        mix3 = _mm256_mullo_epi32(mix3, m);
        mix3 = _mm256_xor_si256(mix3, c3);
    }

    _mm256_store_si256(mix_bytes0, mix0);
    _mm256_store_si256(mix_bytes1, mix1);
    _mm256_store_si256(mix_bytes2, mix2);
    _mm256_store_si256(mix_bytes3, mix3);

    for (uint32_t i = 0; i < mix_len; i += 4) {
        mix[i / 4] = fnv32(fnv32(fnv32(mix[i], mix[i+1]), mix[i+2]), mix[i+3]);
    }

    return;
}

void simple_verify() {
    unsigned char seed[] = "123";

    unsigned char *cache = generate_cache(1024, seed, sizeof(seed) - 1);

    // uint64_t *cache_u32 = (uint64_t *)cache;
    // for (int i = 0; i < 1024 / WORD_BYTES; i++) {
    //     printf("%u ", cache_u32[i]);
    // }
    // printf("\n");

    unsigned char *data = malloc(HASH_BYTES);

    calculate_dataset_item(cache, 1024, 123, data);
    printf("expect: c098aa298730026b820035f4587d37737e3f5733010a61e5f833ee4e7535955f6f3cbc75a65881d3957ec972b4fae8226804a78a09bb450d5d0b5303fb836fc1\n");
    printf("actual: ");
    for (int i = 0; i < 64; i++) {
        printf("%02x", data[i]);
    }
    printf("\n");

    calculate_mask_data(cache, 1024, 123, data);
    printf("expect: 46df553f850fc96736a154a247c7e511a70d5f8c3f8bdd1fc098c64dad77bd7341be534f0538e525cf79cede6c9ecf45b1c1418aba2cfbc5021b78517d87372a\n");
    printf("actual: ");
    for (int i = 0; i < 64; i++) {
        printf("%02x", data[i]);
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

    printf("self_hashimoto_verify() passed\n");
    return;
}

void benchmark_generate_data_item() {
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
    uint64_t items = 1000000;
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
            printf("%02x", data[i]);
        }
        printf("\n");
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double used_time = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("Hash done! Took %0.2fs, rate %0.2f H/s\n", used_time, items / used_time);

    return;
}

void simple_hashimoto_verify() {
    unsigned char seed[] = "123";

    unsigned char *init_hash = malloc(HASH_BYTES);
    unsigned char *mix = aligned_alloc(32, HASH_BYTES * 2);
    SHA512(seed, sizeof(seed) - 1, init_hash);

    unsigned char *cache = generate_cache(1024, seed, sizeof(seed) - 1);

    hashimoto(init_hash, 1024, cache, mix);

    printf("expect: a35905961116a162bd58f9bf83ea40198b7cb2469ddb6844df1cbc9109f194aa\n");
    printf("actual: ");
    for (int i = 0; i < 32; i++) {
        printf("%02x", mix[i]);
    }
    printf("\n");

    hashimoto_avx(init_hash, 1024, cache, mix);
    printf("actual: ");
    for (int i = 0; i < 32; i++) {
        printf("%02x", mix[i]);
    }
    printf(" (avx) \n");

    free(init_hash);
    free(mix);

    return;
}

void benchmark_hashimoto() {
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
    unsigned char *init_hash = malloc(HASH_BYTES);
    unsigned char *mix = aligned_alloc(32, HASH_BYTES * 2);

    uint64_t items = 1000000;
    for (uint64_t idx = 0; idx < items; idx ++) {
        SHA512(&idx, 8, init_hash);
        hashimoto_avx(init_hash, cache_size, cache, mix);

        if (idx % 10000 != 0) {
            continue;
        }

        clock_gettime(CLOCK_MONOTONIC, &endb);
        double used_time = (endb.tv_sec - startb.tv_sec) + (endb.tv_nsec - startb.tv_nsec) / 1e9;
        startb = endb;

        printf("rate %0.2f H/s, item %llu, ", 10000 / used_time, idx);
        for (int i = 0; i < 32; i++) {
            printf("%02x", mix[i]);
        }
        printf("\n");
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    double used_time = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("Hash done! Took %0.2fs, rate %0.2f H/s\n", used_time, items / used_time);

    free(init_hash);
    free(mix);

    return;
}

int main(int argc, char *argv[]) {
    simple_verify();
    self_verify();
    simple_hashimoto_verify();
    // benchmark_generate_data_item();
    benchmark_hashimoto();
    return (0);
}



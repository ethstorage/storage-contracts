# A dagger algorithm with 64 bit dataset
# (that is friendly to CPU but not GPU for 32 bits)

from Crypto.Hash import keccak
import hashlib

HASH_BYTES = 64 # bytes per hash (512 bits)
WORD_BYTES = 8 # bytes per word (64 bits)
WORDS_PER_HASH = 8
CACHE_ROUNDS = 3
DATASET_PARENTS = 256
WORD_MASK = (2 ** (WORD_BYTES * 8)) - 1

def keccak512(bs):
    k = keccak.new(digest_bits=512)
    k.update(bs)
    return k.digest()

def sha512(bs):
    k = hashlib.sha512()
    k.update(bs)
    return k.digest()

# hash512 = keccak512
hash512 = sha512

def generate_cache(cache_size, seed):
    cache = [hash512(seed)]
    for _ in range(1, cache_size // HASH_BYTES):
        cache.append(hash512(cache[-1]))

    rows = len(cache)
    for _ in range(CACHE_ROUNDS):
        for i in range(rows):
            v = int.from_bytes(cache[i][0:4], byteorder="little") % rows
            cache[i] = hash512(bytes(a ^ b for a, b in zip(cache[v], cache[(i - 1 + rows) % rows])))
    return cache

def to_cache_u64(cache):
    cache_u64 = []
    for i in range(len(cache)):
        for off in range(0, HASH_BYTES, WORD_BYTES):
            cache_u64.append(int.from_bytes(cache[i][off:off+WORD_BYTES], byteorder="little"))
    return cache_u64

def fnv64(a, b):
    return ((a * 0x00000100000001B3) & WORD_MASK) ^ b

def words_to_hash(words):
    hash = b''
    for w in words:
        hash += w.to_bytes(length=WORD_BYTES, byteorder="little")
    return hash

def hash_to_words(hash):
    words = []
    for i in range(0, HASH_BYTES, WORD_BYTES):
        words.append(int.from_bytes(hash[i:i+WORD_BYTES], byteorder="little"))
    return words

def calc_dataset_item(cache_u64, i: int):
    rows = len(cache_u64) // WORDS_PER_HASH
    # initialize the mix
    mix = [cache_u64[(i % rows) * WORDS_PER_HASH] ^ i]
    for j in range(1, HASH_BYTES // WORD_BYTES):
        mix.append(cache_u64[(i % rows) * WORDS_PER_HASH + j])

    mix = hash_to_words(hash512(words_to_hash(mix)))

    # fnv it with a lot of random cache nodes based on i
    for j in range(DATASET_PARENTS):
        cache_index = fnv64(i ^ j, mix[j % WORDS_PER_HASH]) % rows
        mix = [fnv64(x, y) for x, y in zip(mix, cache_u64[cache_index * WORDS_PER_HASH: (cache_index+1) * WORDS_PER_HASH])]
    return hash512(words_to_hash(mix))


cache_u64 = to_cache_u64(generate_cache(1024, b'123'))
print(cache_u64)
print(calc_dataset_item(cache_u64, 123).hex())

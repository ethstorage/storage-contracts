from Crypto.Hash import keccak 



def bytes_to_int(h):
    return h0

def fnv256(a, b):
    return ((a * 0x0000000000000000000001000000000000000000000000000000000000000163) ^ b) & (2 ** 256 - 1)

def keccak256(bs):
    k = keccak.new(digest_bits=256)
    k.update(bs)
    return k.digest()

def bytes64(x):
    return x.to_bytes(64, byteorder='big')

def hashimoto(shard_id, data_size, shard_size_bits, nshard_bits, naccess, h0, data_list, idx_list=None, full_data_list=False):
    shard_size = 1 << shard_size_bits
    entries = 1 << (shard_size_bits + nshard_bits)
    for data in data_list:
        assert len(data) == data_size

    # fill h0 into mix (which has the same size as data)
    assert data_size % len(h0) == 0
    mix = bytes()
    for i in range(data_size // len(h0)):
        mix = mix + h0

    h0value = int.from_bytes(h0, byteorder='big')

    mix_off = 0
    for i in range(naccess):
        mix_data = int.from_bytes(mix[mix_off:mix_off+32], byteorder='big')
        mix_data = fnv256(i ^ h0value, mix_data)

        parent = mix_data % entries
        kv_idx = parent + shard_id * shard_size
        if idx_list != None:
            assert idx_list[i] == kv_idx

        if full_data_list:
            data = data_list[kv_idx]
        else:
            data = data_list[i]

        mix = bytes(a ^ b for a, b in zip(mix, data))
        print("i: {}, parent: {}, kv_idx: {}, mix_off: {}, mix_data: {}".format(i, parent, kv_idx, mix_off, mix_data))
        # print(mix.hex())
        mix_off = (mix_data >> (shard_size_bits + nshard_bits)) % (data_size - 32)
    
    return keccak256(mix)
    

def test_large():
    shard_size_bits = 5 # 32
    data_size = 4096

    data_list = []

    l = 0
    for i in range(1 << shard_size_bits):
        data = b''
        for j in range(data_size // 32):
            data = data + keccak256(l.to_bytes(length=4, byteorder='big'))
            l += 1
        data_list.append(data)

    h0 = bytes.fromhex('2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5')
    hashimoto(0, 4096, shard_size_bits, 0, 16, h0, data_list, full_data_list=True)

h0 = bytes.fromhex('2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5')

print(hashimoto(0, 64, 2, 0, 1, h0, [bytes64(2)], [2]).hex())
print(hashimoto(0, 64, 2, 0, 2, h0, [bytes64(2), bytes64(3)], None).hex())
print(hashimoto(0, 64, 2, 1, 2, h0, [bytes64(2), bytes64(1)], None).hex())
print(hashimoto(0, 64, 2, 2, 2, h0, [bytes64(10), bytes64(0)], None).hex())
print(hashimoto(1, 64, 2, 1, 2, h0, [bytes64(10), bytes64(9)], None).hex())

test_large()

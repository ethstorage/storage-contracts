// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStorageManager.sol";
import "./MerkleLib.sol";
import "hardhat/console.sol";

contract DecentralizedKV {
    uint256 public immutable storageCost; // Upfront storage cost (pre-dcf)
    // Discounted cash flow factor in seconds
    // E.g., 0.85 yearly discount in second = 0.9999999948465585 = 340282365167313208607671216367074279424 in Q128.128
    uint256 public immutable dcfFactor;
    uint256 public immutable startTime;
    uint256 public immutable maxKvSize;
    uint40 public lastKvIdx = 0; // number of entries in the store
    uint32 public constant SYSTEM_BLOCK_SIZE = 4096; // 4K bytes is normal SSD minimal fetchable size

    IStorageManager public immutable storageManager;

    struct PhyAddr {
        /* Internal address seeking */
        uint40 kvIdx;
        /* Block Size. aligned with 2^n */
        uint24 kvSize;
        /* Commitment */
        bytes32 hash;
    }

    /* skey - PhyAddr */
    mapping(bytes32 => PhyAddr) internal kvMap;
    /* index - skey, reverse lookup */
    mapping(uint256 => bytes32) internal idxMap;

    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) payable {
        storageManager = _storageManager;
        startTime = _startTime;
        maxKvSize = _maxKvSize;
        storageCost = _storageCost;
        dcfFactor = _dcfFactor;
    }

    function pow(uint256 fp, uint256 n) internal pure returns (uint256) {
        return BinaryRelated.pow(fp, n);
    }


    // Evaluate payment from [t0, t1) seconds
    function _paymentInInterval(
        uint256 x,
        uint256 t0,
        uint256 t1
    ) internal view returns (uint256) {
        return (x * (pow(dcfFactor, t0) - pow(dcfFactor, t1))) >> 128;
    }

    // Evaluate payment from [t0, \inf).
    function _paymentInf(uint256 x, uint256 t0) internal view returns (uint256) {
        return (x * pow(dcfFactor, t0)) >> 128;
    }

    // Evaluate payment from timestamp [fromTs, toTs)
    function _paymentIn(
        uint256 x,
        uint256 fromTs,
        uint256 toTs
    ) internal view returns (uint256) {
        return _paymentInInterval(x, fromTs - startTime, toTs - startTime);
    }

    function _upfrontPayment(uint256 ts) internal view returns (uint256) {
        return _paymentInf(storageCost, ts - startTime);
    }

    // Evaluate the storage cost of a single put().
    function upfrontPayment() public view virtual returns (uint256) {
        return _upfrontPayment(block.timestamp);
    }

    function _preparePut() internal virtual {}

    function generateChunkBits(uint256 dataLen) internal pure returns (uint256) {
        uint256 n = dataLen / SYSTEM_BLOCK_SIZE;
        return (n <= 1) ? 0 : BinaryRelated.getExponentiation(BinaryRelated.findNextPowerOf2(n));
    }

    // Write a large value to KV store.  If the KV pair exists, overrides it.  Otherwise, will append the KV to the KV array.
    function put(bytes32 key, bytes memory data) public payable {
        require(data.length <= maxKvSize, "data too large");
        _preparePut();
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];

        if (paddr.hash == 0) {
            // append (require payment from sender)
            require(msg.value >= upfrontPayment(), "not enough payment");
            paddr.kvIdx = lastKvIdx;
            idxMap[paddr.kvIdx] = skey;
            lastKvIdx = lastKvIdx + 1;
        }
        paddr.kvSize = uint24(data.length);
        uint256 nChunkBits = generateChunkBits(data.length);
        paddr.hash = MerkleLib.merkleRoot(data, SYSTEM_BLOCK_SIZE, nChunkBits);
        kvMap[skey] = paddr;

        storageManager.putRaw(paddr.kvIdx, data);
    }

    // Return the size of the keyed value
    function size(bytes32 key) public view returns (uint256) {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        return kvMap[skey].kvSize;
    }

    // Exist
    function exist(bytes32 key) public view returns (bool) {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        return kvMap[skey].hash != 0;
    }

    // Return the keyed data given off and len.  This function can be only called in JSON-RPC context.
    function get(
        bytes32 key,
        uint256 off,
        uint256 len
    ) public view returns (bytes memory) {
        if (len == 0) {
            return new bytes(0);
        }

        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];
        if (off >= paddr.kvSize) {
            return new bytes(0);
        }

        if (len + off > paddr.kvSize) {
            len = paddr.kvSize - off;
        }

        return storageManager.getRaw(paddr.hash, paddr.kvIdx, off, len);
    }

    // Remove an existing KV pair to a recipient.  Refund the cost accordingly.
    function removeTo(bytes32 key, address to) public {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];
        uint40 kvIdx = paddr.kvIdx;

        require(paddr.hash != 0, "kv not exist");

        // clear kv data
        kvMap[skey] = PhyAddr({kvIdx: 0, kvSize: 0, hash: 0});

        // move last kv to current kv
        bytes32 lastSkey = idxMap[lastKvIdx - 1];
        idxMap[kvIdx] = lastSkey;
        kvMap[lastSkey].kvIdx = kvIdx;

        // remove the last Kv
        idxMap[lastKvIdx - 1] = 0x0;
        lastKvIdx = lastKvIdx - 1;

        storageManager.removeRaw(lastKvIdx, kvIdx);

        payable(to).transfer(upfrontPayment());
    }

    // Remove an existing KV pair.  Refund the cost accordingly.
    function remove(bytes32 key) public {
        removeTo(key, msg.sender);
    }

    // Verify if the value matches a keyed value.
    function verify(bytes32 key, bytes memory data) public view returns (bool) {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];

        require(paddr.hash != 0, "kv not exist");

        if (paddr.kvSize != data.length) {
            return false;
        }
        uint256 nChunkBits = generateChunkBits(data.length);
        return paddr.hash == MerkleLib.merkleRoot(data, SYSTEM_BLOCK_SIZE, nChunkBits);
    }
}

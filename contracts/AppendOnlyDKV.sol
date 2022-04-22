// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStorageManager.sol";

contract AppendOnlyDKV {
    uint256 public immutable storageCost; // Upfront storage cost (pre-dcf)
    // Discounted cash flow factor in seconds
    // E.g., 0.85 yearly discount in second = 0.9999999948465585 = 340282365167313208607671216367074279424 in Q128.128
    uint256 public immutable dcfFactor;
    uint256 public immutable startTime;
    uint256 public immutable maxKvSize;
    uint40 public lastKvIdx = 0; // number of entries in the store

    IStorageManager public immutable storageManager;

    struct PhyAddr {
        uint40 kvIdx;
        uint24 kvSize;
        bytes24 hash;
    }

    mapping(bytes32 => PhyAddr) internal kvMap;

    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) {
        storageManager = _storageManager;
        startTime = _startTime;
        maxKvSize = _maxKvSize;
        storageCost = _storageCost;
        dcfFactor = _dcfFactor;
    }

    function pow(uint256 fp, uint256 n) internal pure returns (uint256) {
        // 1.0 in Q128.128
        uint256 v = 1 << 128;
        while (n != 0) {
            if ((n & 1) == 1) {
                v = (v * fp) >> 128;
            }
            fp = (fp * fp) >> 128;
            n = n / 2;
        }
        return v;
    }

    // Evaluate payment from [t0, t1) seconds
    function payment(
        uint256 x,
        uint256 t0,
        uint256 t1
    ) internal view returns (uint256) {
        return (x * (pow(dcfFactor, t0) - pow(dcfFactor, t1))) >> 128;
    }

    // Evaluate payment from [t0, \inf).
    function paymentInf(uint256 x, uint256 t0) internal view returns (uint256) {
        return (x * pow(dcfFactor, t0)) >> 128;
    }

    // Evaluate the storage cost of a single put().
    function cost() internal view returns (uint256) {
        return paymentInf(storageCost, block.timestamp - startTime);
    }

    // Write a large value to KV store.  Will append the KV to the KV array.
    function put(bytes32 key, bytes memory data) public payable {
        require(data.length <= maxKvSize, "data is too large");
        require(msg.value >= cost(), "not enough storage cost");

        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];

        paddr.kvIdx = lastKvIdx;
        paddr.kvSize = uint24(data.length);
        lastKvIdx = lastKvIdx + 1;

        storageManager.putRaw(paddr.kvIdx, data);
    }

    // Return the size of the keyed value
    function size(bytes32 key) public view returns (uint256) {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        return kvMap[skey].kvSize;
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

        return storageManager.getRaw(paddr.kvIdx, off, len);
    }

    // Remove an existing KV pair.  Refund the cost accordingly.
    // Remove may race with other writes/removes, which is assumed to be non-frequent.
    // function remove(bytes32 key, bytes32 lastSkey) public {
    //     bytes32 skey = keccak256(abi.encode(msg.sender, key));
    //     PhyAddr memory paddr = kvMap[skey];
    //     uint40 kvIdx = paddr.kvIdx;

    //     require(paddr.hash != 0, "kv not exist");

    //     // clear kv data
    //     kvMap[skey] = PhyAddr({kvIdx: 0, kvSize: 0, hash: 0});

    //     // move last kv to current kv
    //     require(kvMap[lastSkey].kvIdx == lastKvIdx - 1, "not last skey");
    //     kvMap[lastSkey].kvIdx = kvIdx;

    //     // remove the last Kv
    //     lastKvIdx = lastKvIdx - 1;

    //     payable(msg.sender).transfer(cost());
    // }

    // Verify if the value matches a keyed value.
    function verify(bytes32 key, bytes memory data) public view returns (bool) {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];

        if (paddr.kvSize != data.length) {
            return false;
        }

        return paddr.hash == bytes24(keccak256(data));
    }
}

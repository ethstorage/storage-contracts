// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DecentralizedKV {
    uint256 public constant KV_SIZE = 256 * 1024;
    uint256 public constant DIFF_ADJ_MULTIPLIER = 1024;
    uint256 public constant TARGET_INTERVAL_SEC = 600;
    uint256 public storageCost = 1e16;
    // 0.85 yearly discount in second = 0.9999999948465585 in Q128.128
    uint256 public dcfFactor = 340282365167313208607671216367074279424;
    uint256 public immutable startTime;
    uint256 public immutable maxKvSize;
    uint40 public lastKvIdx = 0;

    struct PhyAddr {
        uint40 kvIdx;
        uint24 kvSize;
        bytes24 hash;
    }

    mapping (bytes32 => PhyAddr) internal kvMap;
    mapping (uint256 => bytes32) internal idxMap;

    constructor(uint256 _startTime, uint256 _maxKvSize) {
        startTime = _startTime;
        maxKvSize = _maxKvSize;
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
    function payment(uint256 x, uint256 fp, uint256 t0, uint256 t1) internal pure returns (uint256) {
        return (x * (pow(fp, t0) - pow(fp, t1))) >> 128;
    }

    // Evaluate payment from [t0, \inf).
    function paymentInf(uint256 x, uint256 fp, uint256 t0) internal pure returns (uint256) {
        return (x * pow(fp, t0)) >> 128;
    }

    // Evaluate the storage cost of a single put().
    function cost() internal view returns (uint256) {
        return paymentInf(storageCost, dcfFactor, block.timestamp - startTime);
    }

    // Write a large value to KV store.  If the KV pair exists, overrides it.  Otherwise, will append the KV to the KV array.
    function put(bytes32 key, bytes memory data) payable public {
        require(data.length <= maxKvSize, "data is too large");
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];

        if (paddr.kvIdx == 0) {
            // append (require payment from sender)
            require(msg.value >= cost(), "not enough storage cost");
            lastKvIdx = lastKvIdx + 1;
            paddr.kvIdx = lastKvIdx;
            paddr.kvSize = uint24(data.length);
        }
        paddr.hash = bytes24(keccak256(data));
        kvMap[skey] = paddr;
        idxMap[paddr.kvIdx] = skey;
    }
  
    // Remove an existing KV pair.  Refund the cost accordingly.
    function remove(bytes32 key) public {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];
        uint40 kvIdx = paddr.kvIdx;

        require(kvIdx != 0, "kv not exist");

        // clear kv data
        kvMap[skey] = PhyAddr({kvIdx: 0, kvSize: 0, hash: 0});

        // move last kv to current kv
        bytes32 lastSkey = idxMap[lastKvIdx];
        idxMap[kvIdx] = lastSkey;
        kvMap[lastSkey].kvIdx = kvIdx;
        
        // remove the last Kv
        idxMap[lastKvIdx] = 0x0;
        lastKvIdx = lastKvIdx - 1;

        payable(msg.sender).transfer(cost());
    }

    // Verify if the value matches a keyed Value.
    function verify(bytes32 key, bytes memory data) public view returns (bool) {
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr memory paddr = kvMap[skey];

        if (paddr.kvSize != data.length) {
            return false;
        }

        return paddr.hash == bytes24(keccak256(data));
    }
}
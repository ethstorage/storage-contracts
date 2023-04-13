// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStorageManager.sol";
import "./MerkleLib.sol";

contract TestStorageManager is IStorageManager {
    mapping(uint256 => bytes) dataMap;
    uint32 public CHUNK_SIZE; // 4K bytes is normal SSD minimal fetchable size

    constructor(uint32 chunksize) {
        CHUNK_SIZE = chunksize;
    }

    // Get a raw data from underlying storage.
    function getRaw(
        bytes24 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) external view override returns (bytes memory) {
        bytes memory data = dataMap[kvIdx];
        bytes24 dataHash = bytes24(MerkleLib.merkleRootWithMinTree(data, CHUNK_SIZE));
        require(hash == dataHash, "getRaw hash mismatch");

        if (off >= data.length) {
            return bytes("");
        }
        if (len > data.length - off) {
            len = data.length - off;
        }

        bytes memory ret = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            ret[i] = data[i + off];
        }
        return ret;
    }

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes24 kvHash, bytes memory data) external override {
        dataMap[kvIdx] = data;
    }

    // Set a raw data to underlying storage.
    function removeRaw(uint256 fromKvIdx, uint256 toKvIdx) external override {
        dataMap[toKvIdx] = dataMap[fromKvIdx];
        delete dataMap[fromKvIdx];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TestStorageManager.sol";
import "./IStorageManager.sol";
import "./MerkleLib.sol";

contract TestSystemContract is TestStorageManager, ISystemContract {
    uint256 immutable maxKvSize;

    constructor(uint256 _maxKvSize) {
        maxKvSize = _maxKvSize;
    }

    // A CPU-intensive hash algorithm used to generate random KV indices.
    function hash0(bytes32 h) external pure override returns (bytes32) {
        return keccak256(abi.encode(h));
    }

    // Return the masked hash of data.
    // Only return hash of [0, len) bytes after unmasking, assuming the rest bytes are zeros.
    // Return 0x0 if the rest unmasked data have non-zero bytes.
    function maskedDataHashes(
        uint256[] memory,
        uint256[] memory kvSizes,
        bytes[] memory maskedData
    ) external view override returns (bytes32[] memory hashes) {
        hashes = new bytes32[](kvSizes.length);
        for (uint256 i = 0; i < maskedData.length; i++) {
            require(maskedData[i].length == maxKvSize, "size mismatches");
            require(kvSizes[i] <= maxKvSize, "kvSize too large");

            bytes memory mdata = maskedData[i];
            uint256 kvSize = kvSizes[i];
            bytes32 h;
            assembly {
                h := keccak256(add(mdata, 0x20), kvSize)
            }
            // TODO: check the rest data are zeros.
            hashes[i] = h;
        }
    }
}

contract TestSystemContractDaggerHashimoto is TestStorageManager, ISystemContractDaggerHashimoto {
    function unmaskWithEthash(
        uint256,
        bytes memory maskedData
    ) external view override returns (bytes memory) {
        // In current test version we actually use raw data
        // Need to implement once encoding/decoding is ready
        return maskedData;
    }

      function unmaskChunkWithEthash(
        uint64 chunkIdx,
        bytes32 kvHash,
        address miner,
        bytes memory maskedChunk
    ) external view returns (bytes memory){} 
}

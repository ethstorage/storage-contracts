// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStorageManager {
    // Get a raw data from underlying storage.
    function getRaw(
        bytes32 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) external view returns (bytes memory);

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) external;

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function removeRaw(uint256 fromKvIdx, uint256 toKvIdx) external;
}

interface IMiningHash {
    // A CPU-intensive hash algorithm used to generate random KV indices.
    function hash0(bytes32) external view returns (bytes32);

    // Return the masked hash of data.
    // Only return hash of [0, len) bytes after unmasking, assuming the rest bytes are zeros.
    // Return 0x0 if the rest unmasked data have non-zero bytes.
    function maskedDataHashes(
        uint256[] memory kvIdxs,
        uint256[] memory kvSizes,
        bytes[] memory data
    ) external view returns (bytes32[] memory);
}

interface ISystemContract is IStorageManager, IMiningHash {}

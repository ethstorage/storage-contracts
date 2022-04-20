// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStorageManager {
    // Get a raw data from underlying storage.
    function getRaw(
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) external view returns (bytes memory);

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) external;
}

interface IMiningHash {
    // A CPU-intensive hash algorithm used to generate random KV indices.
    function hash0(bytes32) external returns (bytes32);

    // Return the masked hash of data.
    // Only return hash of [0, len) bytes after unmasking, assuming the rest bytes are zeros.
    // Return 0x0 if the rest unmasked data have non-zero bytes.
    function unmaskedDataHash(
        bytes32 skey,
        uint256 len,
        bytes memory data
    ) external returns (bytes32);

    // Return the masked hash of unused KV array.
    function maskedUndataHash(uint256 kvIdx) external returns (bytes32);
}

interface ISystemContract is IStorageManager, IMiningHash {}

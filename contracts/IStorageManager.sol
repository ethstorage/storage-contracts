// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStorageManager {
    // Get a raw data from underlying storage.
    function getRaw(uint256 kvIdx, uint256 off, uint256 len) external view returns (bytes memory);

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) external;
    
}
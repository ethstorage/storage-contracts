// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TestStorageManager.sol";
import "./IStorageManager.sol";
import "hardhat/console.sol";

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
    function checkDaggerData(
        uint256,
        bytes32 kvHash,
        bytes memory maskedData
    ) public view override returns (bool) {
        bytes32 dataHash = keccak256(maskedData);
        console.log("in coming kvHash in 32 bytes");
        console.logBytes32(kvHash);
        console.log("dataHash in 32 bytes");
        console.logBytes32(dataHash);
        console.log("in coming kvHash in 24 bytes");
        console.logBytes24(bytes24(kvHash));
        console.log("dataHash in 24 bytes");
        console.logBytes24(bytes24(dataHash));
        return bytes24(dataHash) == bytes24(kvHash);
    }
}

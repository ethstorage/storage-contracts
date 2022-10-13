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
    /* NOTICE: 
     *   This function assumes users clearly know their submitting data
     *   is LESS OR EQUAL THAN SYSTEM_MINIMAL_BLOCK (which is 4K normally).
     *   So basically this is a trival keccak256 comparison on a full bytes32
     */
    function checkDaggerData(
        uint256,
        bytes32 kvHash,
        bytes memory maskedData
    ) public pure override returns (bool) {
        bytes32[] memory proofs;
        require(proofs.length == 0, "need an empty proofs");
        return checkDaggerDataWithProof(0, kvHash, proofs, maskedData);
    }

    function checkDaggerDataWithProof(
        uint256 idx,
        bytes32 kvHash,
        bytes32[] memory proofs,
        bytes memory maskedData
    ) public pure override returns (bool) {
        bytes32 dataHash = keccak256(maskedData);
        return MerkleLib.verify(dataHash,
                                idx, /* Slice Id */
                                kvHash, /*Merkle Tree Root*/
                                proofs);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../MerkleLib.sol";
import "../IStorageManager.sol";

contract StorageManager is IStorageManager {
    address public constant systemDeployer = 0x0000000000000000000000000000000000033301;
    address public constant sstoragePisaPutRaw = 0x0000000000000000000000000000000000033302;
    address public constant sstoragePisaGetRaw = 0x0000000000000000000000000000000000033303;
    address public constant sstoragePisaUnmaskDaggerData = 0x0000000000000000000000000000000000033304;
    address public constant sstoragePisaRemoveRaw = 0x0000000000000000000000000000000000033305;

    // Get a raw data from underlying storage.
    function getRaw(
        bytes32 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) public view virtual override returns (bytes memory) {
        (bool success, bytes memory data) = address(sstoragePisaGetRaw).staticcall(abi.encode(hash, kvIdx, off, len));
        require(success, "failed to getRaw");
        return data;
    }

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) public virtual override {
        (bool success, ) = address(sstoragePisaPutRaw).call(abi.encode(kvIdx, data));
        require(success, "failed to putRaw");
    }

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function removeRaw(uint256 fromKvIdx, uint256 toKvIdx) public virtual override {
        (bool success, ) = address(sstoragePisaRemoveRaw).call(abi.encode(fromKvIdx, toKvIdx));
        require(success, "failed to removeRaw");
    }

    function unmaskChunk(
        uint64 encodeType,
        uint64 chunkIdx,
        bytes32 kvHash,
        address miner,
        bytes memory maskedChunk
    ) public view virtual override returns (bytes memory) {
        (bool success, bytes memory unmaskedChunk) = address(sstoragePisaUnmaskDaggerData).staticcall(
            abi.encode(encodeType, chunkIdx, kvHash, miner, maskedChunk)
        );
        require(success, "failed to removeRaw");
        return unmaskedChunk;
    }
}

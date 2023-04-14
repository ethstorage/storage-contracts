// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MerkleLib.sol";

contract PrecompileManager {
    address public constant sstoragePisaPutRaw = 0x0000000000000000000000000000000000033302;
    address public constant sstoragePisaGetRaw = 0x0000000000000000000000000000000000033303;
    address public constant sstoragePisaUnmaskDaggerData = 0x0000000000000000000000000000000000033304;
    address public constant sstoragePisaRemoveRaw = 0x0000000000000000000000000000000000033305;
    uint64 public constant ENCODE_ETHHASH = 2;

    // Get a raw data from underlying storage.
    function systemGetRaw(
        bytes24 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) public view virtual returns (bytes memory) {
        uint256 lowKvHash = uint256(uint192(hash));
        (bool success, bytes memory data) = address(0x0000000000000000000000000000000000033303).staticcall(
            abi.encode(lowKvHash, kvIdx, off, len)
        );
        require(success, "failed to systemGetRaw");
        return abi.decode(data, (bytes));
    }

    // Set a raw data to underlying storage.
    function systemPutRaw(uint256 kvIdx, bytes24 kvHash, bytes memory data) public virtual {
        uint256 lowKvHash = uint256(uint192(kvHash));
        (bool success, ) = address(0x0000000000000000000000000000000000033302).call(abi.encode(kvIdx, lowKvHash, data));
        require(success, "failed to putRaw");
    }

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function systemRemoveRaw(uint256 fromKvIdx, uint256 toKvIdx) public virtual {
        (bool success, ) = address(0x0000000000000000000000000000000000033305).call(abi.encode(fromKvIdx, toKvIdx));
        require(success, "failed to systemPutRaw");
    }

    function systemUnmaskChunkWithEthash(
        uint64 chunkIdx,
        bytes24 kvHash,
        address miner,
        bytes memory maskedChunk
    ) public view virtual returns (bytes memory) {
        uint256 lowKvHash = uint256(uint192(kvHash)); // make sure we will get the low 24byte kvHash
        (bool success, bytes memory unmaskedChunk) = address(0x0000000000000000000000000000000000033304).staticcall(
            abi.encode(ENCODE_ETHHASH, chunkIdx, lowKvHash, miner, maskedChunk)
        );
        require(success, "failed to systemUnmaskChunkWithEthash");
        return unmaskedChunk;
    }

    function systemUnmaskWithEthash(
        uint256 kvIdx,
        bytes memory maskedData
    ) public view virtual returns (bytes memory) {}
}

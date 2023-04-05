// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MerkleLib.sol";
import "./IStorageManager.sol";

contract PrecompileManager is ISystemContractDaggerHashimoto {
    address public constant sstoragePisaPutRaw = 0x0000000000000000000000000000000000033302;
    address public constant sstoragePisaGetRaw = 0x0000000000000000000000000000000000033303;
    address public constant sstoragePisaUnmaskDaggerData = 0x0000000000000000000000000000000000033304;
    address public constant sstoragePisaRemoveRaw = 0x0000000000000000000000000000000000033305;
    uint64 public constant ENCODE_ETHHASH = 2;

    // Get a raw data from underlying storage.
    function getRaw(
        bytes32 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) public view virtual returns (bytes memory) {
        (bool success, bytes memory data) = address(sstoragePisaGetRaw).staticcall(abi.encode(msg.sender, hash, kvIdx, off, len));
        require(success, "failed to getRaw");
        return data;
    }

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) public virtual {
        (bool success, ) = address(sstoragePisaPutRaw).call(abi.encode(msg.sender, kvIdx, data));
        require(success, "failed to putRaw");
    }

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function removeRaw(uint256 fromKvIdx, uint256 toKvIdx) public virtual {
        (bool success, ) = address(sstoragePisaRemoveRaw).call(abi.encode(msg.sender, fromKvIdx, toKvIdx));
        require(success, "failed to removeRaw");
    }

    function unmaskChunkWithEthash(
        uint64 chunkIdx,
        bytes24 kvHash,
        address miner,
        bytes memory maskedChunk
    ) public view virtual returns (bytes memory) {
        uint256 lowKvHash = uint256(uint192(kvHash)); // make sure we will get the low 24byte kvHash 
        (bool success, bytes memory unmaskedChunk) = address(sstoragePisaUnmaskDaggerData).staticcall(
            abi.encode(msg.sender, ENCODE_ETHHASH, chunkIdx, lowKvHash, miner, maskedChunk)
        );
        require(success, "failed to unmaskChunkWithEthash");
        return unmaskedChunk;
    }

     function unmaskWithEthash(
        uint256 kvIdx,
        bytes memory maskedData
    ) external view returns (bytes memory){

    }
}

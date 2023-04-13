// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKV.sol";
import "./PrecompileManager.sol";

contract DKVWithPrecompileManagerForTest is DecentralizedKV  {

    ISystemContractDaggerHashimoto public immutable storageManagerTest;
    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        uint256 _chunkSize,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) DecentralizedKV(_maxKvSize, _chunkSize, _startTime, _storageCost, _dcfFactor) {
        storageManagerTest = ISystemContractDaggerHashimoto(address(_storageManager));
    }

    function systemPutRaw(uint256 kvIdx, bytes24 kvHash,bytes memory data) public virtual override{
        // Weird that cannot call precompiled contract like this (solidity issue?)
        // storageManager.putRaw(paddr.kvIdx, data);
        // Use call directly instead.
        (bool success, ) = address(storageManagerTest).call(
            abi.encodeWithSelector(IStorageManager.putRaw.selector, kvIdx,kvHash, data)
        );
        require(success, "failed to putRaw");
    }

    function systemGetRaw(
        bytes24 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) public view virtual override returns (bytes memory) {
        (bool success, bytes memory data) = address(storageManagerTest).staticcall(
            abi.encodeWithSelector(IStorageManager.getRaw.selector, hash,kvIdx,off,len)
        );
        require(success, "failed to systemGetRaw");
        return abi.decode(data,(bytes));
    }

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function systemRemoveRaw(uint256 fromKvIdx, uint256 toKvIdx) public virtual override{
        storageManagerTest.removeRaw(fromKvIdx, toKvIdx);
    }

    function systemUnmaskChunkWithEthash(
        uint64 chunkIdx,
        bytes24 kvHash,
        address miner,
        bytes memory maskedChunk
    ) public view virtual override returns (bytes memory) {
       bytes memory unmaskedData = storageManagerTest.unmaskChunkWithEthash(
                uint64(chunkIdx),
                kvHash,
                miner,
                maskedChunk
            );

        return unmaskedData;
    }

    function systemUnmaskWithEthash(uint256 kvIdx, bytes memory maskedData) public view override returns (bytes memory) {
        return storageManagerTest.unmaskWithEthash(kvIdx, maskedData);
    }
}


contract TestDecentralizedKV is DKVWithPrecompileManagerForTest  {
    uint256 public currentTimestamp;

    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        uint256 _chunkSize,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) DKVWithPrecompileManagerForTest(_storageManager, _maxKvSize, _chunkSize, _startTime, _storageCost, _dcfFactor) {}

    function setTimestamp(uint256 ts) public {
        require(ts > currentTimestamp, "ts");
        currentTimestamp = ts;
    }

    function upfrontPayment() public view override returns (uint256) {
        return _upfrontPayment(currentTimestamp);
    }
}
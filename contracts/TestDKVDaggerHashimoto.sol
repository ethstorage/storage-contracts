// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DKVDaggerHashimoto.sol";
import "./MiningLib.sol";

contract TestDecentralizedKVDaggerHashimoto is DecentralizedKVDaggerHashimoto {
    uint256 public currentTimestamp;
    ISystemContractDaggerHashimoto public immutable systemContractTest;
    constructor(
        Config memory _config,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor,
        bytes32 _genesisHash
    ) DecentralizedKVDaggerHashimoto(_config, _startTime, _storageCost, _dcfFactor, _genesisHash) {
        systemContractTest = _config.systemContract;
    }

    function setTimestamp(uint256 ts) public {
        require(ts > currentTimestamp, "ts");
        currentTimestamp = ts;
    }

    function _preparePut() internal override {
        return _preparePutWithTimestamp(currentTimestamp);
    }

    function mine(
        uint256 startShardId,
        uint256 shardLen,
        address miner,
        uint256 minedTs,
        uint256 nonce,
        bytes32[][] memory proofsDim2,
        bytes[] memory maskedData
    ) public override {
        return _mine(currentTimestamp, startShardId, shardLen, miner, minedTs, nonce, proofsDim2, maskedData);
    }

    function hashimotoKeccak256NonView(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        bytes[] memory maskedData
    ) public returns (bytes32) {
        return _hashimotoKeccak256(startShardId, shardLenBits, hash0, maskedData);
    }

    function calculateDiffAndInitHash(
        uint256 startShardId,
        uint256 shardLen,
        uint256 minedTs
    )
        public
        view
        returns (
            uint256 diff,
            uint256[] memory diffs,
            bytes32 hash0
        )
    {
        return _calculateDiffAndInitHash(startShardId, shardLen, minedTs);
    }

    function rewardMiner(
        uint256 startShardId,
        uint256 shardLen,
        address miner,
        uint256 minedTs,
        uint256[] memory diffs,
        bytes32 hash0
    ) public {
        _rewardMiner(startShardId, shardLen, miner, minedTs, diffs, hash0);
    }

    ///////////////////////////override the precompileManager functions/////////////////////

    function getKVInfo(uint256 kvIdx) public view returns (PhyAddr memory) {
        return kvMap[idxMap[kvIdx]];
    }

    function systemPutRaw(uint256 kvIdx, bytes24 kvHash,bytes memory data) public virtual override{
        // Weird that cannot call precompiled contract like this (solidity issue?)
        // storageManager.putRaw(paddr.kvIdx, data);
        // Use call directly instead.
        (bool success, ) = address(systemContractTest).call(
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
        (bool success, bytes memory data) = address(systemContractTest).staticcall(
            abi.encodeWithSelector(IStorageManager.getRaw.selector, hash,kvIdx,off,len)
        );
        require(success, "failed to systemGetRaw");
        return abi.decode(data,(bytes));
    }

    function systemRemoveRaw(uint256 fromKvIdx, uint256 toKvIdx) public virtual override{
        systemContractTest.removeRaw(fromKvIdx, toKvIdx);
    }

    function systemUnmaskChunkWithEthash(
        uint64 chunkIdx,
        bytes24 kvHash,
        address miner,
        bytes memory maskedChunk
    ) public view virtual override returns (bytes memory) {
       bytes memory unmaskedData = systemContractTest.unmaskChunkWithEthash(
                uint64(chunkIdx),
                kvHash,
                miner,
                maskedChunk
            );

        return unmaskedData;
    }

    function systemUnmaskWithEthash(uint256 kvIdx, bytes memory maskedData) public view override returns (bytes memory) {
        return systemContractTest.unmaskWithEthash(kvIdx, maskedData);
    }
}

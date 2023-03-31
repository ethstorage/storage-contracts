// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DKVDaggerHashimoto.sol";
import "./MiningLib.sol";

contract TestDecentralizedKVDaggerHashimoto is DecentralizedKVDaggerHashimoto {
    uint256 public currentTimestamp;

    constructor(
        Config memory _config,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor,
        bytes32 _genesisHash
    ) DecentralizedKVDaggerHashimoto(_config, _startTime, _storageCost, _dcfFactor, _genesisHash) {}

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
    ) public override{
        return _mine(currentTimestamp, startShardId, shardLen, miner, minedTs, nonce, proofsDim2, maskedData);
    }

    function hashimoto(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        bytes[] memory maskedData
    ) public view returns (bytes32) {
        return _hashimoto(startShardId, shardLenBits, hash0, maskedData);
    }

    function hashimotoNonView(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        bytes[] memory maskedData
    ) public returns (bytes32) {
        return _hashimoto(startShardId, shardLenBits, hash0, maskedData);
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

    function unmaskWithEthash(
        uint256 kvIdx,
        bytes memory maskedData
    ) external view returns (bytes memory){}
}

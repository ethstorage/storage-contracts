// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKVMinable.sol";
import "./MiningLib.sol";

contract TestDecentralizedKVMinable is DecentralizedKVMinable {
    uint256 public currentTimestamp;

    constructor(
        Config memory _config,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor,
        bytes32 _genesisHash
    ) DecentralizedKVMinable(_config, _startTime, _storageCost, _dcfFactor, _genesisHash) {}

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
        bytes[] memory maskedData
    ) public override {
        return _mine(currentTimestamp, startShardId, shardLen, miner, minedTs, nonce, maskedData);
    }

    function calculateRandomAccess(
        uint256 startShardId,
        uint256 shardLen,
        bytes32 hash0,
        uint256 nRandomAccess
    ) public view returns (uint256[] memory kvIdxs, uint256[] memory kvSizes) {
        return _calculateRandomAccess(startShardId, shardLen, hash0, nRandomAccess);
    }

    function checkProofOfRandomAccess(
        uint256 startShardId,
        uint256 shardLen,
        bytes32 hash0,
        bytes[] memory maskedData
    ) public view returns (bytes32 hash) {
        return _checkProofOfRandomAccess(startShardId, shardLen, hash0, maskedData);
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
}

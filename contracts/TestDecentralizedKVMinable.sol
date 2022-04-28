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
        uint256 _dcfFactor
    ) DecentralizedKVMinable(_config, _startTime, _storageCost, _dcfFactor) {}

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
}
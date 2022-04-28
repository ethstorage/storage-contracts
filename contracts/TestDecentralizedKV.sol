// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKV.sol";

contract TestDecentralizedKV is DecentralizedKV {
    uint256 public currentTimestamp;

    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) DecentralizedKV(_storageManager, _maxKvSize, _startTime, _storageCost, _dcfFactor) {}

    function setTimestamp(uint256 ts) public {
        require(ts > currentTimestamp, "ts");
        currentTimestamp = ts;
    }

    function upfrontPayment() public view override returns (uint256) {
        return _upfrontPayment(currentTimestamp);
    }
}

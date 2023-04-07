// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKV.sol";

contract TestDecentralizedKV is DecentralizedKV {
    uint256 public currentTimestamp;

    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        uint256 _chunkSize,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) DecentralizedKV(_storageManager, _maxKvSize, _chunkSize, _startTime, _storageCost, _dcfFactor) {}

    function setTimestamp(uint256 ts) public {
        require(ts > currentTimestamp, "ts");
        currentTimestamp = ts;
    }

    function upfrontPayment() public view override returns (uint256) {
        return _upfrontPayment(currentTimestamp);
    }

    function putRawByDKV(uint256 kvIdx, bytes memory data) public virtual override{
        // Weird that cannot call precompiled contract like this (solidity issue?)
        // storageManager.putRaw(paddr.kvIdx, data);
        // Use call directly instead.
        (bool success, ) = address(storageManager).call(
            abi.encodeWithSelector(IStorageManager.putRaw.selector, kvIdx, data)
        );
        require(success, "failed to putRaw");
    }
}

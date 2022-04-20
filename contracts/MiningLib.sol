// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MiningLib {
    struct MiningInfo {
        bytes32 miningHash;
        uint256 lastMineTime;
        uint256 difficulty;
        uint256 blockMined;
    }

    function mine(MiningInfo storage info, uint256 mineTime, uint256 targetIntervalSec, uint256 cutoff, uint256 diffAdjDivisor, uint256 minDiff, bytes32 miningHash) internal {
        // Check if the diff matches
        // Use modified ETH diff algorithm
        uint256 interval = mineTime - info.lastMineTime;
        uint256 diff = info.difficulty;
        if (interval < targetIntervalSec) {
            diff = diff + (1 - interval / cutoff) * diff / diffAdjDivisor;
        } else {
            uint256 dec = (interval / cutoff - 1) * diff / diffAdjDivisor;
            if (dec + minDiff > diff) {
                diff = minDiff;
            } else {
                diff = diff - dec;
            }
        }

        uint256 required = uint256(2**256 - 1) / diff;
        require(uint256(miningHash) <= required, "diff not match");

        // A block is mined!
        info.blockMined = info.blockMined + 1;
        info.miningHash = miningHash;
        info.difficulty = diff;
        info.lastMineTime = mineTime;
    }
}
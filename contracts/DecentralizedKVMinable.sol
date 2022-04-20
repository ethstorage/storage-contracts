// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKV.sol";
import "./MiningLib.sol";

contract DecentralizedKVMinable is DecentralizedKV {
    struct Config {
        uint256 maxKvSizeBits;
        uint256 shardSizeBits;
        uint256 shardEntryBits;
        uint256 randomChecks;
        uint256 minimumDiff;
        uint256 targetIntervalSec;
        uint256 cutoff;
        uint256 diffAdjDivisor;
        uint256 coinbaseShare; // 10000 = 1.0
        ISystemContract systemContract;
    }
    uint256 public immutable maxKvSizeBits;
    uint256 public immutable shardSizeBits;
    uint256 public immutable shardEntryBits;
    uint256 public immutable randomChecks;
    uint256 public immutable minimumDiff;
    uint256 public immutable targetIntervalSec;
    uint256 public immutable cutoff;
    uint256 public immutable diffAdjDivisor;
    uint256 public immutable coinbaseShare; // 10000 = 1.0
    ISystemContract public immutable systemContract;

    mapping(uint256 => MiningLib.MiningInfo) public infos;

    constructor(
        Config memory _config,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor
    ) DecentralizedKV(_config.systemContract, 1 << _config.maxKvSizeBits, _startTime, _storageCost, _dcfFactor) {
        systemContract = _config.systemContract;
        shardSizeBits = _config.shardSizeBits;
        maxKvSizeBits = _config.maxKvSizeBits;
        shardEntryBits = _config.shardSizeBits - _config.maxKvSizeBits;
        randomChecks = _config.randomChecks;
        minimumDiff = _config.minimumDiff;
        targetIntervalSec = _config.targetIntervalSec;
        cutoff = _config.cutoff;
        diffAdjDivisor = _config.diffAdjDivisor;
        coinbaseShare = _config.coinbaseShare;
    }

    // We allow cross mine multiple shards by aggregate their difficulties.
    function mine(
        uint256 startShardId,
        uint256 shardLen,
        uint256 nonce,
        address miner,
        bytes[] memory data
    ) public {
        // Aggregate the difficulties from multiple shards.
        uint256[] memory diffs = new uint256[](shardLen);
        uint256 diff = 0;
        bytes32 hash0 = bytes32(0);
        for (uint256 i = 0; i < shardLen; i++) {
            uint256 shardId = startShardId + i;
            MiningLib.MiningInfo storage info = infos[shardId];
            diffs[i] = MiningLib.expectedDiff(
                info,
                block.timestamp,
                targetIntervalSec,
                cutoff,
                diffAdjDivisor,
                minimumDiff
            );
            diff = diff + diffs[i];

            hash0 = keccak256(abi.encode(hash0, shardId, infos[shardId].miningHash));
        }

        hash0 = systemContract.hash0(keccak256(abi.encode(hash0, nonce, miner)));
        {
            // avoid stack too deep error
            uint256 matched = 0;
            uint256 totalEntryBits = shardLen * shardEntryBits;
            uint256 totalEntries = 1 << totalEntryBits;
            uint256 startKvIdx = startShardId << shardEntryBits;
            for (uint256 i = 0; i < data.length; i++) {
                uint256 kvIdx = (uint256(hash0) % totalEntries) + startKvIdx;
                bytes32 dataHash;
                if (kvIdx >= lastKvIdx) {
                    dataHash = systemContract.maskedUndataHash(kvIdx);
                } else {
                    bytes32 skey = idxMap[kvIdx];
                    dataHash = systemContract.maskedDataHash(skey, data[i]);

                    if (kvMap[skey].hash == bytes24(keccak256(data[i]))) {
                        matched = matched + 1;
                    }
                }

                hash0 = keccak256(abi.encode(hash0, dataHash));
            }
            // We allow some mismatches if the data happens to be removed/modified.
            require(matched >= randomChecks, "insufficient PoRA");
        }

        // Check if the data matches the hash in metadata.
        uint256 required = uint256(2**256 - 1) / diff;
        require(uint256(hash0) <= required, "diff not match");

        // Send reward to coinbase and miner
        {
            // avoid stack too deep error
            uint256 totalReward = 0;
            uint256 lastShardIdx = lastKvIdx >> shardEntryBits;
            for (uint256 i = 0; i < shardLen; i++) {
                uint256 shardId = startShardId + i;
                MiningLib.MiningInfo storage info = infos[shardId];
                if (i + startShardId < lastShardIdx) {
                    // The shard is full.
                    totalReward += payment(storageCost << shardEntryBits, info.lastMineTime, block.timestamp);
                } else if (i + startShardId == lastShardIdx) {
                    // The shard is not full.
                    uint256 entries = lastKvIdx % (1 << shardEntryBits);
                    totalReward += payment(storageCost * entries, info.lastMineTime, block.timestamp);
                }
            }
            uint256 coinbaseReward = (totalReward * coinbaseShare) / 10000;
            uint256 minerReward = totalReward - coinbaseReward;
            payable(block.coinbase).transfer(coinbaseReward);
            payable(miner).transfer(minerReward);
        }

        //  Mining is successful.  Update info.
        for (uint256 i = 0; i < shardLen; i++) {
            MiningLib.update(infos[startShardId + i], block.timestamp, diffs[i], hash0);
        }
    }
}

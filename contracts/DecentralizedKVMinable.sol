// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKV.sol";
import "./MiningLib.sol";

contract DecentralizedKVMinable is DecentralizedKV {
    struct Config {
        uint256 maxKvSizeBits;
        uint256 chunkSizeBits;
        uint256 shardSizeBits;
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
    bytes32 public immutable emptyValueHash;
    ISystemContract public immutable systemContract;

    mapping(uint256 => MiningLib.MiningInfo) public infos;

    constructor(
        Config memory _config,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor,
        bytes32 _genesisHash
    )
        payable
        DecentralizedKV(_config.systemContract, 1 << _config.maxKvSizeBits, 1 << _config.chunkSizeBits,
                         _startTime, _storageCost, _dcfFactor)
    {
        require(_config.shardSizeBits >= _config.maxKvSizeBits, "config size mismatch");
        require(_config.randomChecks > 0, "randomChecks must be nonzero");
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
        emptyValueHash = keccak256(new bytes(1 << _config.maxKvSizeBits));

        // Shard 0 and 1 is ready to mine.
        infos[0].lastMineTime = _startTime;
        infos[0].miningHash = _genesisHash;
        infos[1].lastMineTime = _startTime;
        infos[1].miningHash = _genesisHash;
    }

    function sendValue() public payable {}

    function _preparePutWithTimestamp(uint256 timestamp) internal {
        if (((lastKvIdx + 1) % (1 << shardEntryBits)) == 0) {
            // Open a new shard.
            // The current shard should be already mined.
            // The next shard is ready to mine (although it has no data).
            // (TODO): Setup shard difficulty as current difficulty / factor?
            // The previous put must cover payment from [lastMineTime, inf) >= that of [block.timestamp, inf)
            uint256 nextShardId = ((lastKvIdx + 1) >> shardEntryBits) + 1;
            infos[nextShardId].lastMineTime = timestamp;
            // use previous shard miningHash to shorten the windows for pre-mining.
            infos[nextShardId].miningHash = infos[nextShardId - 1].miningHash;
        }
    }

    function _preparePut() internal virtual override {
        return _preparePutWithTimestamp(block.timestamp);
    }

    function _calculateRandomAccess(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        uint256 nRandomAccess
    ) internal view returns (uint256[] memory kvIdxs, uint256[] memory kvSizes) {
        kvIdxs = new uint256[](nRandomAccess);
        kvSizes = new uint256[](nRandomAccess);

        uint256 totalEntryBits = shardLenBits + shardEntryBits;
        uint256 totalEntries = 1 << totalEntryBits;
        uint256 startKvIdx = startShardId << shardEntryBits;
        uint256 bits = 256;
        bytes32 rhash = hash0;
        uint256 randomBits = uint256(rhash);

        for (uint256 i = 0; i < nRandomAccess; i++) {
            uint256 kvIdx = (randomBits % totalEntries) + startKvIdx;
            if (kvIdx >= lastKvIdx) {
                kvSizes[i] = maxKvSize;
            } else {
                kvSizes[i] = kvMap[idxMap[kvIdx]].kvSize;
            }
            kvIdxs[i] = kvIdx;

            bits = bits - totalEntryBits;
            randomBits = randomBits >> totalEntryBits;
            if (bits < totalEntryBits) {
                rhash = keccak256(abi.encode(rhash));
                bits = 256;
                randomBits = uint256(rhash);
            }
        }
    }

    function _xorData(bytes memory data0, bytes memory data1) internal pure {
        require(data0.length == data1.length, "xor length mismatch");
        require(data0.length % 32 == 0, "xor length not 32n");
        uint256 dataPtr0;
        uint256 dataPtr1;
        assembly {
            dataPtr0 := add(data0, 0x20)
            dataPtr1 := add(data1, 0x20)
        }
        uint256 dataPtrEnd = dataPtr0 + data0.length;
        while (dataPtr0 < dataPtrEnd) {
            assembly {
                mstore(dataPtr0, xor(mload(dataPtr0), mload(dataPtr1)))
            }
            dataPtr0 = dataPtr0 + 32;
            dataPtr1 = dataPtr1 + 32;
        }
    }

    /* TODO: THIS IS VULNERABLE WHEN FACING LAZY DATA PROVIDER
       It can be affected by an attack vertor, for the way generates random access positions and verifying procedure
       Supppose a lazy data provider only stores 80% of data trunck and submits proof only based on partial data
       It can still pass this checker.
       NOTE: Hashimoto can solve this attack perspective */
    function _checkProofOfRandomAccess(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        bytes[] memory maskedData
    ) internal view returns (bytes32 hash) {
        require(maskedData.length > 0);
        (uint256[] memory kvIdxs, uint256[] memory kvSizes) = _calculateRandomAccess(
            startShardId,
            shardLenBits,
            hash0,
            maskedData.length
        );
        bytes32[] memory dataHashes = systemContract.maskedDataHashes(kvIdxs, kvSizes, maskedData);
        uint256 matched = 0;

        uint256 dataSize = maskedData[0].length;
        bytes memory mixedData = new bytes(dataSize);

        for (uint256 i = 0; i < maskedData.length; i++) {
            require(maskedData[i].length == maxKvSize, "masked data len wrong");

            uint256 kvIdx = kvIdxs[i];
            if (kvIdx >= lastKvIdx) {
                // Expect the provided masked data equals to masked undata.
                if (dataHashes[i] == emptyValueHash) {
                    matched = matched + 1;
                }
            } else {
                bytes32 skey = idxMap[kvIdx];
                // Expect the provided masked data equals to local hash
                if (bytes24(dataHashes[i]) == kvMap[skey].hash) {
                    matched = matched + 1;
                }
            }

            _xorData(mixedData, maskedData[i]);
        }
        // We allow some mismatches if the data happens to be removed/modified.
        require(matched >= randomChecks, "insufficient PoRA");
        return keccak256(abi.encode(hash0, mixedData));
    }

    // Aggregate the difficulties from multiple shards.
    function _calculateDiffAndInitHash(
        uint256 startShardId,
        uint256 shardLen,
        uint256 minedTs
    )
        internal
        view
        returns (
            uint256 diff,
            uint256[] memory diffs,
            bytes32 hash0
        )
    {
        diffs = new uint256[](shardLen);
        diff = 0;
        hash0 = bytes32(0);
        for (uint256 i = 0; i < shardLen; i++) {
            uint256 shardId = startShardId + i;
            MiningLib.MiningInfo storage info = infos[shardId];
            require(minedTs >= info.lastMineTime, "minedTs too small");
            diffs[i] = MiningLib.expectedDiff(info, minedTs, targetIntervalSec, cutoff, diffAdjDivisor, minimumDiff);
            diff = diff + diffs[i];

            hash0 = keccak256(abi.encode(hash0, shardId, infos[shardId].miningHash));
        }
    }

    function lastMinableShardIdx() public view returns (uint256) {
        return (lastKvIdx >> shardEntryBits) + 1;
    }

    function _rewardMiner(
        uint256 startShardId,
        uint256 shardLen,
        address miner,
        uint256 minedTs,
        uint256[] memory diffs,
        bytes32 hash0
    ) internal {
        // Mining is successful.
        // Send reward to coinbase and miner.
        uint256 totalReward = 0;
        uint256 lastPayableShardIdx = lastMinableShardIdx();
        for (uint256 i = 0; i < shardLen; i++) {
            uint256 shardId = startShardId + i;

            if (shardId <= lastPayableShardIdx) {
                // Make a full shard payment.
                MiningLib.MiningInfo storage info = infos[shardId];
                totalReward += _paymentIn(storageCost << shardEntryBits, info.lastMineTime, minedTs);

                // Update mining info.
                MiningLib.update(infos[shardId], minedTs, diffs[i], hash0);
            }
        }
        uint256 coinbaseReward = (totalReward * coinbaseShare) / 10000;
        uint256 minerReward = totalReward - coinbaseReward;
        // TODO: avoid reentrancy attack
        payable(block.coinbase).transfer(coinbaseReward);
        payable(miner).transfer(minerReward);
    }

    function _mine(
        uint256 timestamp,
        uint256 startShardId,
        uint256 shardLenBits,
        address miner,
        uint256 minedTs,
        uint256 nonce,
        bytes[] memory maskedData
    ) internal {
        require(minedTs <= timestamp, "minedTs too large");
        uint256 shardLen = 1 << shardLenBits;
        (uint256 diff, uint256[] memory diffs, bytes32 hash0) = _calculateDiffAndInitHash(
            startShardId,
            shardLen,
            minedTs
        );
        hash0 = systemContract.hash0(keccak256(abi.encode(hash0, miner, minedTs, nonce)));
        hash0 = _checkProofOfRandomAccess(startShardId, shardLen, hash0, maskedData);

        // Check if the data matches the hash in metadata.
        {
            uint256 required = uint256(2**256 - 1) / diff;
            require(uint256(hash0) <= required, "diff not match");
        }

        _rewardMiner(startShardId, shardLen, miner, minedTs, diffs, hash0);
    }

    // We allow cross mine multiple shards by aggregate their difficulties.
    function mine(
        uint256 startShardId,
        uint256 shardLenBits,
        address miner,
        uint256 minedTs,
        uint256 nonce,
        bytes[] memory maskedData
    ) public virtual {
        return _mine(block.timestamp, startShardId, shardLenBits, miner, minedTs, nonce, maskedData);
    }
}

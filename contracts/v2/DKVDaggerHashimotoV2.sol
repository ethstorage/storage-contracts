pragma solidity ^0.8.0;

import "./DecentralizedKVV2.sol";
import "../MiningLib.sol";

/*
 * Decentralized KV with Dagger-Hashimoto mining algorithm.
 */
contract DecentralizedKVDaggerHashimotoV2 is DecentralizedKVV2 {
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
    }
    uint256 public immutable maxKvSizeBits;
    uint256 public immutable shardSizeBits;
    uint256 public immutable shardEntryBits;
    uint256 public immutable chunkLenBits;
    uint256 public immutable randomChecks;
    uint256 public immutable minimumDiff;
    uint256 public immutable targetIntervalSec;
    uint256 public immutable cutoff;
    uint256 public immutable diffAdjDivisor;
    uint256 public immutable coinbaseShare; // 10000 = 1.0
    bytes32 public immutable emptyValueHash;
    // ISystemContractDaggerHashimoto public immutable systemContract;

    mapping(uint256 => MiningLib.MiningInfo) public infos;

    constructor(
        Config memory _config,
        uint256 _startTime,
        uint256 _storageCost,
        uint256 _dcfFactor,
        bytes32 _genesisHash
    )
        payable
        DecentralizedKVV2(1 << _config.maxKvSizeBits, 1 << _config.chunkSizeBits, _startTime, _storageCost, _dcfFactor)
    {
        /* Assumptions */
        require(_config.shardSizeBits >= _config.maxKvSizeBits, "shardSize too small");
        require(_config.maxKvSizeBits >= _config.chunkSizeBits, "maxKvSize too small");
        require(_config.randomChecks > 0, "At least one checkpoint needed");

        shardSizeBits = _config.shardSizeBits;
        maxKvSizeBits = _config.maxKvSizeBits;
        shardEntryBits = _config.shardSizeBits - _config.maxKvSizeBits;
        chunkLenBits = _config.maxKvSizeBits - _config.chunkSizeBits;
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
                dataPtr0 := add(dataPtr0, 32)
                dataPtr1 := add(dataPtr1, 32)
            }
        }
    }

    function _xorData4(bytes memory data0, bytes memory data1) internal pure {
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
                dataPtr0 := add(dataPtr0, 32)
                dataPtr1 := add(dataPtr1, 32)
                mstore(dataPtr0, xor(mload(dataPtr0), mload(dataPtr1)))
                dataPtr0 := add(dataPtr0, 32)
                dataPtr1 := add(dataPtr1, 32)
                mstore(dataPtr0, xor(mload(dataPtr0), mload(dataPtr1)))
                dataPtr0 := add(dataPtr0, 32)
                dataPtr1 := add(dataPtr1, 32)
                mstore(dataPtr0, xor(mload(dataPtr0), mload(dataPtr1)))
                dataPtr0 := add(dataPtr0, 32)
                dataPtr1 := add(dataPtr1, 32)
            }
        }
    }

    function _fnv256(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a * 0x0000000000000000000001000000000000000000000000000000000000000163) ^ b;
        }
    }

    /*
     * Run a modified hashimoto hash,
     * with Merkle inclusion proofs
     */
    function _hashimotoMerkleProof(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        address miner,
        bytes32[][] memory proofsDim2,
        bytes[] memory maskedData
    ) internal view returns (bytes32) {
        require(maskedData.length == randomChecks, "data vs checks: length mismatch");
        require(proofsDim2.length == randomChecks, "proofs vs checks: length mismatch");
        uint256 maxKvSize = 1 << maxKvSizeBits;
        uint256 rows = 1 << (shardEntryBits + shardLenBits + chunkLenBits);

        for (uint256 i = 0; i < randomChecks; i++) {
            require(maskedData[i].length == chunkSize, "invalid proof size");
            uint256 parent = uint256(hash0) % rows;
            uint256 chunkIdx = parent + (startShardId << (shardEntryBits + chunkLenBits));
            uint256 kvIdx = chunkIdx >> chunkLenBits;
            chunkIdx = chunkIdx % (1 << chunkLenBits);
            bytes memory data = maskedData[i];
            /* NOTICE: Now we have kvIdx and chunkIdx both generated from hash0
             *         The difficulty should increase intrinsically */
            require(
                _checkDaggerDataWithProof(kvMap[idxMap[kvIdx]], chunkIdx, miner, proofsDim2[i], data),
                "invalid access proof"
            );

            assembly {
                mstore(data, hash0)
                hash0 := keccak256(data, add(maxKvSize, 0x20))
                mstore(data, maxKvSize)
            }
        }
        return hash0;
    }

    uint64 public constant ENCODE_ETHHASH = 1;
    bytes32 public constant EMPTY_CHUNK_4KB_HASH = 0xa8bae11751799de4dbe638406c5c9642c0e791f2a65e852a05ba4fdf0d88e3e6;

    function _checkDaggerDataWithProof(
        PhyAddr memory kvInfo,
        uint256 chunkIdx,
        address miner,
        bytes32[] memory proofs,
        bytes memory maskedChunkData
    ) internal view returns (bool) {
        bytes memory unmaskedData = unmaskChunk(ENCODE_ETHHASH, uint64(chunkIdx), kvInfo.hash, miner, maskedChunkData);
        // todo : verify exceed chunk and no full chunk
        uint256 chunksNumPerKV = maxKvSizeBits / chunkLenBits;
        uint256 startChunkIdx = chunksNumPerKV * kvInfo.kvIdx;

        uint256 relaChunkIdx = chunkIdx - startChunkIdx;
        uint256 accumulatorChunkSize = (relaChunkIdx + 1) * chunkLenBits;
        uint256 tSize = relaChunkIdx * chunkLenBits;
        bytes32 dataHash;
        if (accumulatorChunkSize > kvInfo.kvSize) {
            // todo :verify empty
            return keccak256(unmaskedData) == EMPTY_CHUNK_4KB_HASH;
        } else if (tSize < kvInfo.kvSize && kvInfo.kvSize <= accumulatorChunkSize) {
            //todo :concat
            uint256 datasize = kvInfo.kvSize - tSize;
            dataHash = keccak256(cut(unmaskedData, datasize));
        } else {
            dataHash = keccak256(unmaskedData);
        }

        bytes32 rootFromProofs = MerkleLib.calculateRootWithProof(dataHash, relaChunkIdx, proofs);
        /* NOTICE: Due to our design of PhyAddr, only front 24 bytes
         *         are valid. We only validate that part.
         * With no doubt, it introduces some vulnerability compared
         * with a standard Merkle validation. It is a trade-off,
         * if we want to put all meta data into a single bytes32(opcode length)
         */
        return bytes24(rootFromProofs) == bytes24(kvInfo.hash);
    }

    function cut(bytes memory data, uint256 newlen) internal pure returns (bytes memory) {
        require(newlen <= data.length, "cut fail");
        assembly {
            mstore(data, newlen)
        }
        return data;
    }

    // Aggregate the difficulties from multiple shards.
    function _calculateDiffAndInitHash(
        uint256 startShardId,
        uint256 shardLen,
        uint256 minedTs
    ) internal view returns (uint256 diff, uint256[] memory diffs, bytes32 hash0) {
        diffs = new uint256[](shardLen);
        diff = 0;
        hash0 = bytes32(0);
        for (uint256 i = 0; i < shardLen; i++) {
            uint256 shardId = startShardId + i;
            MiningLib.MiningInfo storage info = infos[shardId];
            require(minedTs >= info.lastMineTime, "minedTs too small");
            diffs[i] = MiningLib.expectedDiff(info, minedTs, targetIntervalSec, cutoff, diffAdjDivisor, minimumDiff);
            diff = diff + diffs[i];

            hash0 = keccak256(abi.encode(hash0, shardId, info.miningHash));
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

    /* In fact, this is on-chain function used for verifying whether what a miner claims,
       is satisfying the truth, or not.
       Nonce, along with maskedData, associated with mineTs and idx, are proof.
       On-chain verifier will go same routine as off-chain data host, will check the soundness of data,
       by running hashimoto algorithm, to get hash H. Then if it passes the difficulty check,
       the miner, or say the proof provider, shall be rewarded by the token number from out economic models */
    function _mine(
        uint256 timestamp,
        uint256 startShardId,
        uint256 shardLenBits,
        address miner,
        uint256 minedTs,
        uint256 nonce,
        bytes32[][] memory proofsDim2,
        bytes[] memory maskedData
    ) internal {
        require(minedTs <= timestamp, "minedTs too large");
        uint256 shardLen = 1 << shardLenBits;
        (uint256 diff, uint256[] memory diffs, bytes32 hash0) = _calculateDiffAndInitHash(
            startShardId,
            shardLen,
            minedTs
        );

        hash0 = keccak256(abi.encode(hash0, miner, minedTs, nonce));
        hash0 = _hashimotoMerkleProof(startShardId, shardLenBits, hash0, miner, proofsDim2, maskedData);

        // Check if the data matches the hash in metadata.
        {
            uint256 required = uint256(2 ** 256 - 1) / diff;
            require(uint256(hash0) <= required, "diff not match");
        }

        _rewardMiner(startShardId, shardLen, miner, minedTs, diffs, hash0);
    }

    // We allow cross mine multiple shards by aggregating their difficulties.
    // For some reasons, we never use checkIdList but if we remove it, we will get
    // a `Stack too deap error`
    function mine(
        uint256 startShardId,
        uint256 shardLenBits,
        address miner,
        uint256 minedTs,
        uint256 nonce,
        bytes32[][] memory proofsDim2,
        bytes[] memory maskedData
    ) public virtual {
        return _mine(block.timestamp, startShardId, shardLenBits, miner, minedTs, nonce, proofsDim2, maskedData);
    }
}

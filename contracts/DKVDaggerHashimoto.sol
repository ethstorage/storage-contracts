// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedKV.sol";
import "./MiningLib.sol";

/*
 * Decentralized KV with Dagger-Hashimoto mining algorithm.
 */
contract DecentralizedKVDaggerHashimoto is DecentralizedKV {
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
        ISystemContractDaggerHashimoto systemContract;
    }

    bytes32 public immutable EMPTY_CHUNK_HASH;

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
    ISystemContractDaggerHashimoto public immutable systemContract;

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
        /* Assumptions */
        require(_config.shardSizeBits >= _config.maxKvSizeBits, "shardSize too small");
        require(_config.maxKvSizeBits >= _config.chunkSizeBits, "maxKvSize too small");
        require(_config.randomChecks > 0, "At least one checkpoint needed");

        systemContract = _config.systemContract;
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
        EMPTY_CHUNK_HASH = keccak256(new bytes(1 << _config.chunkSizeBits));
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

    /* ON CHAIN VERFICATION */
    function checkDaggerDataWithProof(
        uint256 chunkIdx,
        PhyAddr memory kvInfo,
        bytes32[] memory proofs,
        bytes memory unmaskedData
    ) public view returns (bool) {
        uint256 chunksNumPerKV = 1 << chunkLenBits;
        uint256 maxChunkIdx = lastKvIdx * chunksNumPerKV-1;

        if (chunkIdx > maxChunkIdx){
            return keccak256(unmaskedData) == EMPTY_CHUNK_HASH;
        }
        
        uint256 mchunkSize = chunkSize;
        uint256 chunkLeafIdx = chunkIdx % chunksNumPerKV;
        uint256 maxLeafIdx = MerkleLib.getMaxLeafsNum(kvInfo.kvSize,mchunkSize) - 1;
        if (chunkLeafIdx >  maxLeafIdx){
            return keccak256(unmaskedData) == EMPTY_CHUNK_HASH;
        }

        // we should consider two special cases:
        // 1. the chunk-leaf is the last chunk with empty being full with zero 
        // 2. the data is not full with the whole chunk-leaf 
        bytes32 dataHash;
        if (chunkLeafIdx == maxLeafIdx && (maxLeafIdx * mchunkSize) >= kvInfo.kvSize  ) {
            dataHash = bytes32(0);
        }else if(chunkLeafIdx * mchunkSize < kvInfo.kvSize && kvInfo.kvSize <= (chunkLeafIdx+1) * mchunkSize){
            uint256 validUnmaskedDataLen = kvInfo.kvSize - chunkLeafIdx * mchunkSize;
            assembly{
                dataHash := keccak256(add(unmaskedData,0x20),validUnmaskedDataLen)
            }
        }else{
            dataHash = keccak256(unmaskedData);
        }
        
        bytes32 rootFromProofs = MerkleLib.calculateRootWithProof(dataHash, chunkLeafIdx, proofs);
        /* NOTICE: Due to our design of PhyAddr, only front 24 bytes
         *         are valid. We only validate that part.
         * With no doubt, it introduces some vulnerability compared 
         * with a standard Merkle validation. It is a trade-off,
         * if we want to put all meta data into a single bytes32(opcode length)
         */
        return bytes24(rootFromProofs) == bytes24(kvInfo.hash);
    }

    /* NOTICE: 
     *   This function assumes users clearly know their submitting data
     *   is LESS OR EQUAL THAN SYSTEM_MINIMAL_BLOCK (which is 4K normally).
     *   So basically this is a trival keccak256 comparison on a full bytes32
     */
    function checkDaggerData(
        uint256,
        PhyAddr memory kvInfo,
        bytes memory maskedData
    ) public view returns (bool) {
        bytes32[] memory proofs;
        require(proofs.length == 0, "need an empty proofs");
        return checkDaggerDataWithProof(0, kvInfo, proofs, maskedData);
    }

    /* END OF ON CHAIN VERFICATION */

    /*
     * Run a modified hashimoto hash.
     */
    function _hashimoto(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        bytes[] memory maskedData
    ) internal view returns (bytes32) {
        /*
         * The parameters vs Ethash
         * elementSize: 32 (bytes) vs 4 (bytes)
         * mixSize: 4096 vs 128
         * mixEntries: 4096/32= vs 32
         * loopAccess: 16 vs 64
         * lookupTableBytes: 4096 vs 64
         * use XOR with random position of mix data intead of FNV with fixed mix positions for faster speed
         */
        require(maskedData.length == randomChecks, "data vs checks: length mismatch");
        uint256 maxKvSize = 1 << maxKvSizeBits;
        bytes memory mix = new bytes(maxKvSize);
        for (uint256 j = 32; j <= maxKvSize; j += 32) {
            assembly {
                mstore(add(mix, j), hash0)
            }
        }

        uint256 rows = 1 << (shardEntryBits + shardLenBits);

        uint256 mixOff = 0;
        for (uint256 i = 0; i < randomChecks; i++) {
            require(maskedData[i].length == maxKvSize, "invalid proof size");
            uint256 mixData;
            {
                uint256 off = mixOff + 32;
                assembly {
                    mixData := mload(add(mix, off))
                }
            }
            // Check if the random accessed data is correct.
            mixData = _fnv256(i ^ uint256(hash0), mixData);
            uint256 parent = mixData % rows;
            uint256 kvIdx = parent + (startShardId << shardEntryBits);
            bytes memory data = systemContract.unmaskWithEthash(kvIdx, maskedData[i]);
            require(checkDaggerData(kvIdx, kvMap[idxMap[kvIdx]], data), "invalid access proof");

            // Next mixOff
            mixOff = (mixData >> (shardEntryBits + shardLenBits)) % (maxKvSize - 32);

            // Xor access data (instead of fnv for faster speed)
            if ((maxKvSize % 128) == 0) {
                _xorData4(mix, data);
            } else {
                _xorData(mix, data);
            }
        }
        return keccak256(mix);
    }

    /*
     * Run a modified hashimoto hash.
     * This is eaiser running in evm, and it is designed for smaller size
     */
    function _hashimotoKeccak256(
        uint256 startShardId,
        uint256 shardLenBits,
        bytes32 hash0,
        bytes[] memory maskedData
    ) internal view returns (bytes32) {
        /* Assumption check */
        require(maskedData.length == randomChecks, "data vs checks: length mismatch");
        require(maskedData[0].length == chunkSize, "too large data uploaded");

        uint256 maxKvSize = 1 << maxKvSizeBits;
        uint256 rows = 1 << (shardEntryBits + shardLenBits);

        for (uint256 i = 0; i < randomChecks; i++) {
            require(maskedData[i].length == maxKvSize, "invalid proof size");
            uint256 parent = uint256(hash0) % rows;
            uint256 kvIdx = parent + (startShardId << shardEntryBits);
            bytes memory data = systemContract.unmaskWithEthash(kvIdx, maskedData[i]);
            require(checkDaggerData(kvIdx, kvMap[idxMap[kvIdx]], data), "invalid access proof");

            assembly {
                mstore(data, hash0)
                hash0 := keccak256(data, add(maxKvSize, 0x20))
                mstore(data, maxKvSize)
            }
        }
        return hash0;
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
        // calculate the number of chunks range of the sample check 
        uint256 rows = 1 << (shardEntryBits + shardLenBits + chunkLenBits);

        for (uint256 i = 0; i < randomChecks; i++) {
            uint256 mChunkSize = chunkSize;
            require(maskedData[i].length == mChunkSize, "invalid proof size");
            uint256 parent = uint256(hash0) % rows;
            uint256 chunkIdx = parent + (startShardId << (shardEntryBits + chunkLenBits));
            uint256 kvIdx = chunkIdx >> chunkLenBits;
            PhyAddr memory kvInfo = kvMap[idxMap[kvIdx]];

            /* NOTICE: kvInfo.hash is the bytes24-hash , the value will be set at the front 
            *          24-byte when it converts to bytes32-hash */
            bytes memory unmaskedData = systemContract.unmaskChunkWithEthash(
                uint64(chunkIdx),
                kvInfo.hash,
                miner,
                maskedData[i]
            );
            /* NOTICE: Now we have kvIdx and chunkIdx both generated from hash0
             *         The difficulty should increase intrinsically */
            require(checkDaggerDataWithProof(chunkIdx, kvInfo, proofsDim2[i], unmaskedData), "invalid access proof");

            /* NOTICE: we should use the maskedChunkData merged with the `hash0` to calculate the new `hash0` 
            *          because the miner executes this `hash0` calculation off-chain in this way. */
            bytes memory maskedChunkData = maskedData[i];
            assembly {
                mstore(maskedChunkData, hash0)
                hash0 := keccak256(maskedChunkData, add(mChunkSize, 0x20))
                mstore(maskedChunkData, mChunkSize)
            }
        }
        return hash0;
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
        hash0 = _hashimotoMerkleProof(startShardId, shardLenBits, hash0, miner,proofsDim2, maskedData);

        // Check if the data matches the hash in metadata.
        {
            uint256 required = uint256(2**256 - 1) / diff;
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

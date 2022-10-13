// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStorageManager {
    // Get a raw data from underlying storage.
    function getRaw(
        bytes32 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) external view returns (bytes memory);

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) external;

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function removeRaw(uint256 fromKvIdx, uint256 toKvIdx) external;
}

interface IMiningHash {
    // A CPU-intensive hash algorithm used to generate random KV indices.
    function hash0(bytes32) external view returns (bytes32);

    // Return the masked hash of data.
    // Only return hash of [0, len) bytes after unmasking, assuming the rest bytes are zeros.
    // Return 0x0 if the rest unmasked data have non-zero bytes.
    // Use batched method that allow concurrent computation.
    function maskedDataHashes(
        uint256[] memory kvIdxs,
        uint256[] memory kvSizes,
        bytes[] memory data
    ) external view returns (bytes32[] memory);
}

interface IDaggerHash {
    // Return if the maskedData matches underlying data
    function checkDaggerData(
        uint256 kvIdx,
        bytes32 kvHash,
        bytes memory maskedData
    ) external view returns (bool);

    function checkDaggerDataWithProof(
        uint256 kvIdx,
        bytes32 kvHash,
        bytes32[] memory proofs,
        bytes memory maskedData
    ) external view returns (bool);
}

interface ISystemContract is IStorageManager, IMiningHash {}

interface ISystemContractDaggerHashimoto is IStorageManager, IDaggerHash {}

library BinaryRelated {
    function pow(uint256 fp, uint256 n) internal pure returns (uint256) {
        // 1.0 in Q128.128
        uint256 v = 1 << 128;
        while (n != 0) {
            if ((n & 1) == 1) {
                v = (v * fp) >> 128;
            }
            fp = (fp * fp) >> 128;
            n = n / 2;
        }
        return v;
    }

    function findNextPowerOf2(uint256 n) internal pure returns (uint256) {
        n = n-1;
        while ((n & (n-1) != 0)) n = n & (n-1);
        return n << 1;
    }

    function getExponentiation(uint256 n) internal pure returns (uint256) {
        uint256 cnt = 0;
        while(n != 0) {
            n = n >> 1;
            cnt++;
        }
        return cnt-1;
    }
}

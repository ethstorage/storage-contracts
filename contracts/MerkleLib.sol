// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MerkleLib {
    // Calculate the Merkle root of a given data with chunk size and number of maximum chunks in the data limit.
    function merkleRoot(
        bytes memory data,
        uint256 chunkSize,
        uint256 nChunkBits
    ) internal pure returns (bytes32) {
        uint256 nChunks = 1 << nChunkBits;
        bytes32[] memory nodes = new bytes32[](nChunks);
        for (uint256 i = 0; i < nChunks; i++) {
            bytes32 hash;
            uint256 off = i * chunkSize;
            if (off >= data.length) {
                // empty mean the leaf is zero
                break;
            }
            uint256 len = data.length - off;
            if (len >= chunkSize) {
                len = chunkSize;
            }
            assembly {
                hash := keccak256(add(add(data, 0x20), off), len)
            }
            nodes[i] = hash;
        }
        uint256 n = nChunks;
        while (n != 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                nodes[i] = keccak256(abi.encode(nodes[i * 2], nodes[i * 2 + 1]));
            }

            n = n / 2;
        }
        return nodes[0];
    }

    // Verify the if the hash of a chunk data is in the chunks
    function verify(
        bytes32 dataHash,
        uint256 chunkIdx,
        bytes32 root,
        bytes32[] memory proofs
    ) internal pure returns (bool) {
        bytes32 hash = dataHash;
        uint256 nChunkBits = proofs.length;
        require(chunkIdx < (1 << nChunkBits), "chunkId overflows");
        for (uint256 i = 0; i < nChunkBits; i++) {
            if (chunkIdx % 2 == 0) {
                hash = keccak256(abi.encode(hash, proofs[i]));
            } else {
                hash = keccak256(abi.encode(proofs[i], hash));
            }
            chunkIdx = chunkIdx / 2;
        }
        /* NOTICE: Due to our design of PhyAddr, only front 24 bytes
         *         are valid. We only validate that part.
         * With no doubt, it introduces some vulnerability compared 
         * with a standard Merkle validation. It is a trade-off,
         * if we want to put all meta data into a single bytes32(opcode length)
         */
        return bytes24(hash) == bytes24(root);
    }

    function getProof(
        bytes memory data,
        uint256 chunkSize,
        uint256 nChunkBits,
        uint256 chunkIdx
    ) internal pure returns (bytes32[] memory) {
        uint256 nChunks = 1 << nChunkBits;
        require(chunkIdx < nChunks, "index out of scope");
        bytes32[] memory nodes = new bytes32[](nChunks);
        for (uint256 i = 0; i < nChunks; i++) {
            bytes32 hash;
            uint256 off = i * chunkSize;
            if (off >= data.length) {
                // empty is zero leaf
                break;
            }
            uint256 len = data.length - off;
            if (len >= chunkSize) {
                len = chunkSize;
            }
            assembly {
                hash := keccak256(add(add(data, 0x20), off), len)
            }
            nodes[i] = hash;
        }
        uint256 n = nChunks;
        uint256 proofIdx = 0;
        bytes32[] memory proofs = new bytes32[](nChunkBits);
        while (n != 1) {
            proofs[proofIdx] = nodes[(chunkIdx / 2) * 2 + 1 - (chunkIdx % 2)];
            for (uint256 i = 0; i < n / 2; i++) {
                nodes[i] = keccak256(abi.encode(nodes[i * 2], nodes[i * 2 + 1]));
            }

            n = n / 2;
            chunkIdx = chunkIdx / 2;
            proofIdx = proofIdx + 1;
        }
        return proofs;
    }
}

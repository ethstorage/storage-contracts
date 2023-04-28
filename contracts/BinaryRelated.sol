// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        n = n - 1;
        n = n | (n >> 1);
        n = n | (n >> 2);
        n = n | (n >> 4);
        n = n | (n >> 8);
        n = n | (n >> 16);
        n = n | (n >> 32);
        n = n | (n >> 64);
        n = n | (n >> 128);
        n = n + 1;
        return n;
    }
}
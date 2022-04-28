// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStorageManager.sol";

contract TestStorageManager is IStorageManager {
    mapping(uint256 => bytes) dataMap;

    // Get a raw data from underlying storage.
    function getRaw(
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) external view override returns (bytes memory) {
        bytes memory data = dataMap[kvIdx];
        if (off >= data.length) {
            return bytes("");
        }
        if (len > data.length - off) {
            len = data.length - off;
        }

        bytes memory ret = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            ret[i] = data[i + off];
        }
        return ret;
    }

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) external override {
        dataMap[kvIdx] = data;
    }
}

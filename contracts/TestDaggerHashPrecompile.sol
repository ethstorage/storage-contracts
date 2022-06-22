// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TestDecentralizedKV.sol";
import "./CallerLibraries.sol";

contract TestDaggerHashPrecompile {
    uint256 immutable maxKvSize;

    constructor(uint256 _maxKvSize) {
        maxKvSize = _maxKvSize;
    }

    fallback (bytes calldata data) external returns (bytes memory) {
        require(data.length == maxKvSize + 32, "incorrect data size");
        bytes memory maskedData = data;
        bytes32 paddr;
        uint256 maxKvSizeTmp = maxKvSize;
        // Obtain the first 32 bytes as physical addr, and the rest bytes as maskedData
        assembly {
            paddr := mload(add(maskedData, 32))
            mstore(add(maskedData, 32), maxKvSizeTmp)
            maskedData := add(maskedData, 32)
        }
        bytes32 dataHash = keccak256(maskedData);
        bytes24 kvHash = bytes24(paddr);
        return abi.encode(bytes24(dataHash) == bytes24(kvHash));
    }
}

contract TestKVWithDaggerHash is TestDecentralizedKV {
    address daggerHashAddr;

    constructor(
        IStorageManager _storageManager,
        uint256 _maxKvSize,
        address _daggerHashAddr
    ) TestDecentralizedKV(_storageManager, _maxKvSize, 0, 0, 0) {
        daggerHashAddr = _daggerHashAddr;
    }

    function checkDaggerHash(bytes32 key, bytes memory maskedData) public view returns (bool) {
        // Obtain the value of the physical address directly from storage slot.
        uint256 paddrValue;
        bytes32 skey = keccak256(abi.encode(msg.sender, key));
        PhyAddr storage paddr = kvMap[skey];
        assembly {
            paddrValue := sload(paddr.slot)
        }
        return DaggerHashCaller.checkDaggerData(daggerHashAddr, paddrValue, maskedData);
    }
}

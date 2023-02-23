// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStorageManager.sol";
contract StorageManager {

    address constant public systemDeployer =  0x0000000000000000000000000000000000033301;
    address constant public sstoragePisaPutRaw =  0x0000000000000000000000000000000000033302;
    address constant public sstoragePisaGetRaw =  0x0000000000000000000000000000000000033303;
    address constant public sstoragePisaUnmaskDaggerData =  0x0000000000000000000000000000000000033304;
    address constant public sstoragePisaRemoveRaw =  0x0000000000000000000000000000000000033305;
    
    // Get a raw data from underlying storage.
    function getRaw(
        bytes32 hash,
        uint256 kvIdx,
        uint256 off,
        uint256 len
    ) internal view returns (bytes memory){
        (bool success, bytes memory data) = address(sstoragePisaGetRaw).staticcall(
            abi.encodePacked(hash, kvIdx, off, len)
        );
        require(success, "failed to getRaw");
        return data;
    }

    // Set a raw data to underlying storage.
    function putRaw(uint256 kvIdx, bytes memory data) internal {
        (bool success, ) = address(sstoragePisaPutRaw).call(
            abi.encodePacked(kvIdx, data)
        );
        require(success, "failed to putRaw");
    }

    // Remove by moving data from fromKvIdx to toKvIdx and clear fromKvIdx
    function removeRaw(uint256 fromKvIdx, uint256 toKvIdx) internal {
         (bool success, ) = address(sstoragePisaRemoveRaw).call(
            abi.encodePacked(fromKvIdx, toKvIdx)
        );
        require(success, "failed to removeRaw");
    }
}
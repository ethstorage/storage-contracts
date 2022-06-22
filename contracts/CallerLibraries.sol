// SPDX-License-Identifier: MIT

// Libraries for callers with efficient gas optimization.
// Mostly achieved by modifying bytes32 data inplace with compact representation.
pragma solidity ^0.8.0;

/*
 * Directly call checkDaggerData by modifying the data inplace.
 * This could reduce the cost of allocating and initializing abi encoded input of normal call.
 */
library DaggerHashCaller {
    function checkDaggerData(
        address contractAddr,
        uint256 paddr,
        bytes memory maskedData
    ) internal view returns (bool) {
        uint256 tmp = maskedData.length;
        bool result;
        bool success;

        assembly {
            mstore(maskedData, paddr) // override the length as input argument

            success := staticcall(
                20000, // max 20k gas
                contractAddr, // to addr
                maskedData, // inputs are stored at location x
                add(tmp, 0x20), // inputs len
                maskedData, // store output over input (saves space)
                0x20 // outputs are 32 bytes long
            )

            result := mload(maskedData) // load bytes32 return
            mstore(maskedData, tmp) // recover the data length
        }

        return success && result;
    }
}

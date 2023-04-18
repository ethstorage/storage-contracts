pragma solidity ^0.8.0;

// DKVHash 0x0000000000000000000000000000000003330001
// PrecompileManager 0x0000000000000000000000000000000003330003
contract SystemDeployer {
    address public constant systemDeployer = 0x0000000000000000000000000000000000033301;

    string public errmsg;

    function deploySystem(address target) public returns (bool success, bytes memory result) {
        bytes memory data = abi.encode(target);
        (success, result) = systemDeployer.call(data);
        require(success, "failed to deploy");
    }

    function contractCodeSize(address addr) public view returns (uint256) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(addr)
        }
        return codeSize;
    }

    function getBalance(address addr) public view returns (uint256) {
        return addr.balance;
    }
}

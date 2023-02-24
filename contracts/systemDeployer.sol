pragma solidity ^0.8.0;

//0x0000000000000000000000000000000000033301
//
//0x0000000000000000000000000000000003330001

import "./IStorageManager.sol";
contract deployer{
    address public constant systemDeployer =  0x0000000000000000000000000000000000033301;

    string public errmsg;

    function encoding(bytes32 kv, bytes memory data) public pure returns(bytes memory){
        return abi.encode(kv,data);
    }

    function encodingWithSelector(bytes32 kvIdx, bytes memory data) public pure returns(bytes memory){
       return abi.encodeWithSelector(IStorageManager.putRaw.selector, kvIdx, data);
    }

    // 0x0000000000000000000000000000000000033301
    // 0x0000000000000000000000000000000003330001
    function deploySystem(address addr,address target) public returns(bool success , bytes memory result){
        bytes memory data = abi.encode(target);
        (success , result)= addr.call(data);
        require(success, "failed to deploy");
    }

    function contractCodeSize(address addr) public view returns(uint256){
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(addr)
        }
        return codeSize;
    }

    function contractCode(address addr,uint256 codeStart,uint256 getCodeSize) public view returns(uint256,bytes memory){
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(addr)
        }
        
        bytes memory codeData = new bytes(getCodeSize);

        assembly {
            extcodecopy(addr,add(codeData,0x20),codeStart,getCodeSize)
        }

        return (codeSize,codeData);
    }
}
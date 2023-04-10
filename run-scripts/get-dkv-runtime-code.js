const { web3 } = require("hardhat");
const { ethers } = require("hardhat");


async function main(){
    const MinabledKV = await ethers.getContractFactory(
        "DecentralizedKVDaggerHashimoto"
      );

      const scAddr= "0x0000000000000000000000000000000003330003";
      //maxKvSizeBits chunkSizeBits  shardSizeBits(18)
      const kv = await MinabledKV.deploy(
        [12, 12, 18, 16, 100, 300, 40, 1024, 1000, scAddr],
        0,
        0,
        0,
        ethers.utils.formatBytes32String("")
      );
      await kv.deployed();

      let code = await ethers.provider.getCode(kv.address);
      console.log(code)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  
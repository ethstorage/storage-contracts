const { web3 } = require("hardhat");
const { ethers } = require("hardhat");


async function main(){
    const getFac = await ethers.getContractFactory(
      "GetRuntimeCode"
    );

    const get = await getFac.deploy()
    await get.deployed();

    const MinabledKV = await ethers.getContractFactory(
        "DecentralizedKVDaggerHashimoto"
      );

      const scAddr= "0x0000000000000000000000000000000003330003";
      //maxKvSizeBits chunkSizeBits  shardSizeBits(18)
      // const kv = await MinabledKV.deploy(
      //   [17, 12, 35, 16, 100, 300, 40, 1024, 1000, scAddr],
      //   1,
      //   0,
      //   0,
      //   ethers.utils.formatBytes32String("0x1111111111111111111111111111111111111111111111111111111111111111")
      // );
      const kv = await MinabledKV.deploy(
        [17, 12, 25, 16, 100, 300, 40, 1024, 1000, "0x0000000000000000000000000000000003330003"],
        1,
        0,
        0,
        "0x1111111111111111111111111111111111111111111111111111111111111111"
      );
      // const kv = await MinabledKV.deploy(
      //   [12, 12, 18, 16, 100, 300, 40, 1024, 1000, scAddr],
      //   1,
      //   0,
      //   0,
      //   "0x1111111111111111111111111111111111111111111111111111111111111111"
      // );
      await kv.deployed();

      let code = await ethers.provider.getCode(kv.address);

      let runtime_code = await get.getcode(kv.address);

      let sInfo = await kv.infos(0)
      console.log(sInfo);
      console.log("============code==============")
      console.log(code)
      console.log("============runtime code==============")
      console.log(runtime_code)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  
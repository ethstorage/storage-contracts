const { ethers } = require("hardhat");

async function main() {
  const address = "0x0000000000000000000000000000000003330001"
  const Contract = await ethers.getContractFactory('DecentralizedKVDaggerHashimoto');
  const contract = Contract.attach(address);
  const tx = await contract.initShard(1, "0x1111111111111111111111111111111111111111111111111111111111111111");
  await tx.wait();
  console.log("initShard success");
  // const info = await contract.infos(0)
  // console.log("info", info)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
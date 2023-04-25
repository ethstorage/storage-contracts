const { ethers } = require("hardhat");

async function main() {
  console.log("signer", (await ethers.getSigner()).address)
  console.log("signer's balance", await (await ethers.getSigner()).getBalance())

  const Contract = await ethers.getContractFactory('SystemDeployer');
  const contract = await Contract.deploy();
  await contract.deployed();
  console.log('Contract deployed at ' + contract.address);
  const addr = "0x0000000000000000000000000000000003330001"
  const tx = await contract.deploySystem(addr);
  await tx.wait();
  console.log("deploySystem success", addr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
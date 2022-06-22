const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("DaggerHash Test", function () {
  it("small-value", async function () {
    const StorageManager = await ethers.getContractFactory("TestStorageManager");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const TestDaggerHashPrecompile = await ethers.getContractFactory("TestDaggerHashPrecompile");
    const dg = await TestDaggerHashPrecompile.deploy(4);
    await dg.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestKVWithDaggerHash");
    const kv = await DecentralizedKV.deploy(sm.address, 4, dg.address);
    await kv.deployed();

    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344");
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 4)).to.equal(
      "0x11223344"
    );

    expect(await kv.checkDaggerHash("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344"))
      .to.be.true;
  });
});

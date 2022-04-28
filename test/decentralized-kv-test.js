const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { defaultAbiCoder } = require("ethers/lib/utils");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("DecentralizedKV Test", function () {
  it("put/get", async function() {
    const StorageManager = await ethers.getContractFactory("TestStorageManager");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestDecentralizedKV");
    const kv = await DecentralizedKV.deploy(sm.address, 1024, 0, 0, 0);
    await kv.deployed();

    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344");
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 4)).to.equal("0x11223344");
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 1, 2)).to.equal("0x2233");
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 2, 3)).to.equal("0x3344");
  });
});
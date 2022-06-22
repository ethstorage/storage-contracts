const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);
var hexlify4 = (x) => ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 4);

describe("DaggerHash Test", function () {
  it("small-value", async function () {
    const StorageManager = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
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
    expect(
      await kv.checkDaggerHashNormal("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344")
    ).to.be.true;
  });

  it("4KB-value", async function () {
    const StorageManager = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const TestDaggerHashPrecompile = await ethers.getContractFactory("TestDaggerHashPrecompile");
    const dg = await TestDaggerHashPrecompile.deploy(4096);
    await dg.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestKVWithDaggerHash");
    const kv = await DecentralizedKV.deploy(sm.address, 4096, dg.address);
    await kv.deployed();

    let d = "0x";
    for (let j = 0; j < 4096 / 32; j++) {
      d = ethers.utils.hexConcat([d, ethers.utils.keccak256(hexlify4(j))]);
    }

    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", d);
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 4096)).to.equal(d);

    expect(await kv.checkDaggerHash("0x0000000000000000000000000000000000000000000000000000000000000001", d)).to.be
      .true;
    expect(await kv.checkDaggerHashNormal("0x0000000000000000000000000000000000000000000000000000000000000001", d)).to
      .be.true;

    // Uncomment for gas report
    await kv.checkDaggerHashNonView("0x0000000000000000000000000000000000000000000000000000000000000001", d);
    await kv.checkDaggerHashDirectNonView("0x0000000000000000000000000000000000000000000000000000000000000001", d);
    await kv.checkDaggerHashNormalNonView("0x0000000000000000000000000000000000000000000000000000000000000001", d);
  });

  it("8KB-value", async function () {
    const StorageManager = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const TestDaggerHashPrecompile = await ethers.getContractFactory("TestDaggerHashPrecompile");
    const dg = await TestDaggerHashPrecompile.deploy(8192);
    await dg.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestKVWithDaggerHash");
    const kv = await DecentralizedKV.deploy(sm.address, 8192, dg.address);
    await kv.deployed();

    let d = "0x";
    let d32 = ethers.utils.keccak256(hexlify4(0));
    for (let j = 0; j < 8192 / 32; j++) {
      d = ethers.utils.hexConcat([d, d32]);
    }

    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", d);
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 8192)).to.equal(d);

    expect(await kv.checkDaggerHash("0x0000000000000000000000000000000000000000000000000000000000000001", d)).to.be
      .true;
    expect(await kv.checkDaggerHashNormal("0x0000000000000000000000000000000000000000000000000000000000000001", d)).to
      .be.true;

    // Uncomment for gas report
    await kv.checkDaggerHashNonView("0x0000000000000000000000000000000000000000000000000000000000000001", d);
    await kv.checkDaggerHashDirectNonView("0x0000000000000000000000000000000000000000000000000000000000000001", d);
    await kv.checkDaggerHashNormalNonView("0x0000000000000000000000000000000000000000000000000000000000000001", d);
  });
});

const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);
var PadTo32 = (x) => x.padEnd(66, "0");

describe("DecentralizedKV Test", function () {
  it("calculateRandomAccessSmall", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy([5, 8, 6, 0, 60, 40, 1024, 0, sc.address], 0, 0, 0);
    await kv.deployed();

    for (let i = 0; i < 12; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), ethers.utils.hexlify(i));
    }

    expect(await kv.get(ethers.utils.formatBytes32String("5"), 0, 1)).to.equal("0x05");

    let h0 = "0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5";
    let r = await kv.calculateRandomAccess(0, 1, h0, 6);
    expect(r[0][0]).to.be.equal(5);
    expect(r[0][1]).to.be.equal(11);
    expect(r[0][2]).to.be.equal(15);
    expect(r[0][3]).to.be.equal(13);
    expect(r[0][4]).to.be.equal(5);
    expect(r[0][5]).to.be.equal(10);

    expect(r[1][0]).to.be.equal(1);
    expect(r[1][1]).to.be.equal(1);
    expect(r[1][2]).to.be.equal(32);
    expect(r[1][3]).to.be.equal(32);
    expect(r[1][4]).to.be.equal(1);
    expect(r[1][5]).to.be.equal(1);
  });

  it("calculateRandomAccessLarge", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(8);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy([12, 31, 20, 0, 60, 40, 1024, 0, sc.address], 0, 0, 0);
    await kv.deployed();

    let h0 = "0x0102030405060708091011121314151617181920212223242526272829303132";
    let r = await kv.calculateRandomAccess(1, 19, h0, 20);
    expect(r[0][0]).to.be.equal(172489716018 + 524288);
    expect(r[0][1]).to.be.equal(53965265052 + 524288);
    expect(r[0][5]).to.be.equal(69056601120 + 524288);
    // new hash with h1 = 0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5
    expect(r[0][6]).to.be.equal(107099840437 + 524288);
    expect(r[0][11]).to.be.equal(213266026186 + 524288);
    // new hash with h2 = 0x54f1e57f92d012c3be597693f9db498c8a9c5c78418c90d7f6feb4cec764c372
    expect(r[0][12]).to.be.equal(63474811762 + 524288);
    expect(r[0][17]).to.be.equal(267550477070 + 524288);
  });

  it("checkProofOfRandomAccess", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy([5, 8, 6, 0, 60, 40, 1024, 0, sc.address], 0, 0, 0);
    await kv.deployed();

    for (let i = 0; i < 12; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), ethers.utils.hexlify(i));
    }

    let h0 = "0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5";
    let r0 = await kv.checkProofOfRandomAccess(0, 1, h0, [
      PadTo32(ethers.utils.hexlify(5)),
      PadTo32(ethers.utils.hexlify(11)),
      PadTo32(ethers.utils.hexlify(15)), // should be zero
      PadTo32(ethers.utils.hexlify(13)), // should be zero
      PadTo32(ethers.utils.hexlify(5)),
      PadTo32(ethers.utils.hexlify(10)),
      PadTo32(ethers.utils.hexlify(15)), // should be zero
      PadTo32(ethers.utils.hexlify(14)), // should be zero
      PadTo32(ethers.utils.hexlify(8)),
      PadTo32(ethers.utils.hexlify(1)),
    ]);
    let r1 = await kv.checkProofOfRandomAccess(0, 1, h0, [
      PadTo32(ethers.utils.hexlify(5)),
      PadTo32(ethers.utils.hexlify(11)),
      PadTo32("0x"), // should be zero
      PadTo32("0x"), // should be zero
      PadTo32(ethers.utils.hexlify(5)),
      PadTo32(ethers.utils.hexlify(10)),
      PadTo32("0x"), // should be zero
    ]);
    await expect(
      kv.checkProofOfRandomAccess(0, 1, h0, [
        PadTo32(ethers.utils.hexlify(5)),
        PadTo32(ethers.utils.hexlify(11)),
        PadTo32(ethers.utils.hexlify(15)), // should be zero
        PadTo32(ethers.utils.hexlify(13)), // should be zero
        PadTo32(ethers.utils.hexlify(5)),
        PadTo32(ethers.utils.hexlify(10)),
        PadTo32(ethers.utils.hexlify(15)), // should be zero
        PadTo32(ethers.utils.hexlify(14)), // should be zero
        PadTo32(ethers.utils.hexlify(8)),
      ])
    ).to.be.revertedWith("insufficient PoRA");
  });
});
const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("DecentralizedKV Test", function () {
  it("calculateRandomAccess", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(8);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy([12, 31, 20, 0, 60, 40, 1024, 0, sc.address], 0, 0, 0);
    await kv.deployed();

    let h0 = "0x0102030405060708091011121314151617181920212223242526272829303132";
    let r = await kv.calculateRandomAccess(1, 2, h0, 20);
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
});

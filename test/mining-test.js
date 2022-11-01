const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);
var padRight32 = (x) => x.padEnd(66, "0");
var padLeft32 = (x) => ethers.utils.hexZeroPad(x, 32);
var formatB32Str = (x) => ethers.utils.formatBytes32String(x);
var keccak256 = (x) => ethers.utils.keccak256(x);

describe("Basic Func Test", function () {
  it("calculateRandomAccessSmall", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy(
      [5, 5, 8, 6, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
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
    const kv = await MinabledKV.deploy(
      [12, 12, 31, 20, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
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
    const kv = await MinabledKV.deploy(
      [5, 5, 8, 6, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
    await kv.deployed();

    for (let i = 0; i < 12; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), ethers.utils.hexlify(i));
    }

    let h0 = "0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5";
    let r0 = await kv.checkProofOfRandomAccess(0, 1, h0, [
      padRight32(ethers.utils.hexlify(5)),
      padRight32(ethers.utils.hexlify(11)),
      padRight32(ethers.utils.hexlify(15)), // should be zero
      padRight32(ethers.utils.hexlify(13)), // should be zero
      padRight32(ethers.utils.hexlify(5)),
      padRight32(ethers.utils.hexlify(10)),
      padRight32(ethers.utils.hexlify(15)), // should be zero
      padRight32(ethers.utils.hexlify(14)), // should be zero
      padRight32(ethers.utils.hexlify(8)),
      padRight32(ethers.utils.hexlify(1)),
    ]);
    let r1 = await kv.checkProofOfRandomAccess(0, 1, h0, [
      padRight32(ethers.utils.hexlify(5)),
      padRight32(ethers.utils.hexlify(11)),
      padRight32("0x"), // should be zero
      padRight32("0x"), // should be zero
      padRight32(ethers.utils.hexlify(5)),
      padRight32(ethers.utils.hexlify(10)),
      padRight32("0x"), // should be zero
    ]);
    await expect(
      kv.checkProofOfRandomAccess(0, 1, h0, [
        padRight32(ethers.utils.hexlify(5)),
        padRight32(ethers.utils.hexlify(11)),
        padRight32(ethers.utils.hexlify(15)), // should be zero
        padRight32(ethers.utils.hexlify(13)), // should be zero
        padRight32(ethers.utils.hexlify(5)),
        padRight32(ethers.utils.hexlify(10)),
        padRight32(ethers.utils.hexlify(15)), // should be zero
        padRight32(ethers.utils.hexlify(14)), // should be zero
        padRight32(ethers.utils.hexlify(8)),
      ])
    ).to.be.revertedWith("insufficient PoRA");
  });

  it("calculateDiffAndInitHash", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy([5, 5, 8, 6, 10, 60, 40, 1024, 0, sc.address], 0, 0, 0, formatB32Str("genesis"));
    await kv.deployed();

    let m0 = await kv.calculateDiffAndInitHash(0, 1, 5);
    let h0 = keccak256(ethers.utils.concat([formatB32Str(""), padLeft32("0x00"), formatB32Str("genesis")]));
    expect(m0).to.be.eql([ToBig("10"), [ToBig("10")], h0]);

    let m1 = await kv.calculateDiffAndInitHash(1, 1, 5);
    let h1 = keccak256(ethers.utils.concat([formatB32Str(""), padLeft32("0x01"), formatB32Str("genesis")]));
    expect(m1).to.be.eql([ToBig("10"), [ToBig("10")], h1]);

    let m01 = await kv.calculateDiffAndInitHash(0, 2, 5);
    let h01 = keccak256(ethers.utils.concat([h0, padLeft32("0x01"), formatB32Str("genesis")]));
    expect(m01).to.be.eql([ToBig("20"), [ToBig("10"), ToBig("10")], h01]);
  });
});

describe("rewardMiner", function () {
  it("rewardMiner with 0.5 dcf/s", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);

    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy(
      [5, 5, 8, 6, 10, 60, 40, 1024, 0, sc.address],
      5,
      "1000000000000000000", // for all
      "170141183460469231731687303715884105728", // 0.5
      formatB32Str("genesis")
    );
    await kv.deployed();

    // Total should be 1.0 * 2 shards * 8
    await kv.sendValue({ value: ethers.utils.parseEther("16.0") });

    await kv.rewardMiner(0, 2, wallet.address, 8, [10, 10], padLeft32("0x"));
    // time 5,6,7 will have (0.5 + 0.25 + 0.125) * 2 shards * 8 = 14.0
    expect(await wallet.getBalance()).to.be.equal("14000000000000000000");

    await kv.rewardMiner(0, 2, wallet.address, 9, [10, 10], padLeft32("0x"));
    // time 8 will have (0.5 + 0.25 + 0.125 + 0.0625) * 2 shards * 8 = 15.0
    expect(await wallet.getBalance()).to.be.equal("15000000000000000000");

    await kv.rewardMiner(0, 2, wallet.address, 200, [10, 10], padLeft32("0x"));
    // time 8 will have (0.5 + 0.25 + 0.125 + 0.0625) * 2 shards * 8 = 15.0
    expect(await wallet.getBalance()).to.be.equal("16000000000000000000");
  });

  it("rewardMiner with 0.5 dcf/s with put", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);

    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy(
      [5, 5, 8, 6, 10, 60, 40, 1024, 0, sc.address],
      5,
      "1000000000000000000", // for all
      "170141183460469231731687303715884105728", // 0.5
      formatB32Str("genesis")
    );
    await kv.deployed();

    // Total should be 1.0 * 2 shards * 8
    await kv.sendValue({ value: ethers.utils.parseEther("16.0") });

    await kv.rewardMiner(0, 4, wallet.address, 6, [10, 10], padLeft32("0x"));
    // time 5 will have 0.5 * 2 shards * 8 = 8
    expect(await wallet.getBalance()).to.be.equal("8000000000000000000");

    // Put 4 elements
    for (let i = 0; i < 4; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), ethers.utils.hexlify(i), {
        value: "1000000000000000000",
      });
    }

    await kv.rewardMiner(0, 4, wallet.address, 7, [10, 10], padLeft32("0x"));
    // time 5 will have (0.5 + 0.25) * 2 shards * 8 = 12
    expect(await wallet.getBalance()).to.be.equal("12000000000000000000");

    // Put 3 elements
    for (let i = 4; i < 7; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), ethers.utils.hexlify(i), {
        value: "1000000000000000000",
      });
    }

    await kv.rewardMiner(0, 4, wallet.address, 8, [10, 10], padLeft32("0x"));
    // time 5 will have (0.5 + 0.25 + 0.125) * 2 shards * 8 = 14
    expect(await wallet.getBalance()).to.be.equal("14000000000000000000");

    await kv.setTimestamp(8);
    // Put 1 element, this will create a new shard at time 8
    for (let i = 7; i < 8; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), ethers.utils.hexlify(i), {
        value: "1000000000000000000",
      });
    }

    await kv.rewardMiner(0, 4, wallet.address, 9, [10, 10, 10], padLeft32("0x"));
    // time 5 will have (0.5 + 0.25 + 0.125 + 0.0625) * 2 shards * 8 + 0.0625 * 8 = 15.5
    expect(await wallet.getBalance()).to.be.equal("15500000000000000000");

    await kv.rewardMiner(0, 4, wallet.address, 10, [10, 10, 10], padLeft32("0x"));
    // time 5 will have (0.5 + 0.25 + 0.125 + 0.0625 + 0.03125) * 2 shards * 8 + (0.0625 + 0.03125) * 8 = 16.25
    expect(await wallet.getBalance()).to.be.equal("16250000000000000000");

    // Remove 1 element, this will remove the new shard at time 10
    await kv.remove(ethers.utils.formatBytes32String("7"));

    await kv.rewardMiner(0, 4, wallet.address, 11, [10, 10, 10], padLeft32("0x"));
    // time 5 will have (0.5 + 0.25 + 0.125 + 0.0625 + 0.03125) * 2 shards * 8 + (prevous) = 16.5
    expect(await wallet.getBalance()).to.be.equal("16500000000000000000");
  });

  it("rewardMiner with 0.5 dcf/s and dynamic shards", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);

    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy(
      [5, 5, 8, 6, 10, 60, 40, 1024, 0, sc.address],
      5,
      "1000000000000000000", // for all
      "170141183460469231731687303715884105728", // 0.5
      formatB32Str("genesis")
    );
    await kv.deployed();

    // Total should be 1.0 * 2 shards * 8
    await kv.sendValue({ value: ethers.utils.parseEther("16.0") });

    await kv.rewardMiner(1, 2, wallet.address, 8, [10, 10], padLeft32("0x"));
    // time 5,6,7 will have (0.5 + 0.25 + 0.125) * 1 shards * 8 = 7.0
    expect(await wallet.getBalance()).to.be.equal("7000000000000000000");

    await kv.rewardMiner(0, 1, wallet.address, 9, [10, 10], padLeft32("0x"));
    // time 8 will have (0.5 + 0.25 + 0.125 + 0.0625) * 1 shards * 8 + (previous) = 7.5 + 7
    expect(await wallet.getBalance()).to.be.equal("14500000000000000000");

    await kv.rewardMiner(0, 2, wallet.address, 200, [10, 10], padLeft32("0x"));
    // time 8 will have (0.5 + 0.25 + 0.125 + 0.0625) * 2 shards * 8 = 15.0
    expect(await wallet.getBalance()).to.be.equal("16000000000000000000");
  });

  it("rewardMiner with 0.5 dcf/y", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);
    
    const SystemContract = await ethers.getContractFactory("TestSystemContract");
    const sc = await SystemContract.deploy(32);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVMinable");
    const kv = await MinabledKV.deploy(
      [5, 5, 8, 6, 10, 60, 40, 1024, 0, sc.address],
      100,
      "1000000000000000000", // for all
      "340282365784068676928457747575078800565", // 0.5
      formatB32Str("genesis")
    );
    await kv.deployed();

    // Total should be 1.0 * 2 shards * 8
    await kv.sendValue({ value: ethers.utils.parseEther("16.0") });

    await kv.rewardMiner(0, 2, wallet.address, 605, [10, 10], padLeft32("0x"));
    expect(await wallet.getBalance()).to.be.equal("26994934308550");

    await kv.rewardMiner(0, 2, wallet.address, 3605, [10, 10], padLeft32("0x"));
    expect(await wallet.getBalance()).to.be.equal("187359941751564");

    await kv.rewardMiner(0, 2, wallet.address, 3600 * 24 * 365 + 5, [10, 10], padLeft32("0x"));
    expect(await wallet.getBalance()).to.be.equal("1599995429565947066");
  });
});

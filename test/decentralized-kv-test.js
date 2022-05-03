const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("DecentralizedKV Test", function () {
  it("put/get/remove", async function () {
    const StorageManager = await ethers.getContractFactory("TestStorageManager");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestDecentralizedKV");
    const kv = await DecentralizedKV.deploy(sm.address, 1024, 0, 0, 0);
    await kv.deployed();

    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344");
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 4)).to.equal(
      "0x11223344"
    );
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 1, 2)).to.equal("0x2233");
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 2, 3)).to.equal("0x3344");

    await kv.remove("0x0000000000000000000000000000000000000000000000000000000000000001");
    expect(await kv.exist("0x0000000000000000000000000000000000000000000000000000000000000001")).to.equal(false);
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 4)).to.equal("0x");
  });

  it("put/remove with payment", async function () {
    const [addr0] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(addr0.provider);

    const StorageManager = await ethers.getContractFactory("TestStorageManager");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestDecentralizedKV");
    // 1e18 cost with 0.5 discount rate per second
    const kv = await DecentralizedKV.deploy(
      sm.address,
      1024,
      0,
      "1000000000000000000",
      "170141183460469231731687303715884105728"
    );
    await kv.deployed();

    expect(await kv.upfrontPayment()).to.equal("1000000000000000000");
    await expect(
      kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344")
    ).to.be.revertedWith("not enough payment");
    await expect(
      kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344", {
        value: "900000000000000000",
      })
    ).to.be.revertedWith("not enough payment");
    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344", {
      value: ethers.utils.parseEther("1.0"),
    });

    await kv.setTimestamp(1);
    expect(await kv.upfrontPayment()).to.equal("500000000000000000");
    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000002", "0x33445566", {
      value: ethers.utils.parseEther("0.5"),
    });

    await kv.setTimestamp(4);
    expect(await kv.upfrontPayment()).to.equal("62500000000000000");
    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000003", "0x778899", {
      value: ethers.utils.parseEther("0.0625"),
    });

    await kv.removeTo("0x0000000000000000000000000000000000000000000000000000000000000001", wallet.address);
    expect(await wallet.getBalance()).to.equal(ethers.utils.parseEther("0.0625"));
    expect(await kv.exist("0x0000000000000000000000000000000000000000000000000000000000000001")).to.equal(false);
    expect(await kv.get("0x0000000000000000000000000000000000000000000000000000000000000001", 0, 4)).to.equal("0x");
  });

  it("put with payment and yearly 0.9 dcf", async function () {
    const StorageManager = await ethers.getContractFactory("TestStorageManager");
    const sm = await StorageManager.deploy();
    await sm.deployed();
    const DecentralizedKV = await ethers.getContractFactory("TestDecentralizedKV");
    // 1e18 cost with 0.90 discount rate per year
    const kv = await DecentralizedKV.deploy(
      sm.address,
      1024,
      0,
      "1000000000000000000",
      "340282365784068676928457747575078800565"
    );
    await kv.deployed();

    expect(await kv.upfrontPayment()).to.equal("1000000000000000000");
    await expect(
      kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344")
    ).to.be.revertedWith("not enough payment");
    await expect(
      kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344", {
        value: "900000000000000000",
      })
    ).to.be.revertedWith("not enough payment");
    await kv.put("0x0000000000000000000000000000000000000000000000000000000000000001", "0x11223344", {
      value: ethers.utils.parseEther("1.0"),
    });

    await kv.setTimestamp(1);
    expect(await kv.upfrontPayment()).to.equal("999999996659039970");
    await kv.setTimestamp(3600 * 24 * 365);
    expect(await kv.upfrontPayment()).to.equal("900000000000000000");
  });
});

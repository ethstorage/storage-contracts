const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);
var padRight64 = (x) => x.padEnd(130, "0");
var padLeft64 = (x) => ethers.utils.hexZeroPad(x, 64);
var hexlify64 = (x) => padLeft64(ethers.utils.hexlify(x));
var hexlify4 = (x) => ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 4);
var keccak256 = (x) => ethers.utils.keccak256(x);

describe("Basic Func Test", function () {
  it("hashimoto-tiny", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(32);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 64 bytes per data, 4 entries in shard, 1 random access
    const kv = await MinabledKV.deploy(
      [6, 8, 1, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
    await kv.deployed();

    for (let i = 0; i < 16; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), hexlify64(i));
    }

    let h0 = "0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5";
    let r0 = await kv.hashimoto(0, 0, h0, [padRight64(hexlify64(2))]);
    expect(r0).to.equal("0x8c8285a007382a35628355faf9b037fd3523d6aa3d40b6187fcd9f7681023c23");

    let r1 = await kv.hashimoto(0, 1, h0, [padRight64(hexlify64(2))]);
    expect(r1).to.equal("0x8c8285a007382a35628355faf9b037fd3523d6aa3d40b6187fcd9f7681023c23");

    let r2 = await kv.hashimoto(0, 2, h0, [padRight64(hexlify64(10))]);
    expect(r2).to.equal("0x3ab8ce32981e789e67abf48d7753da99792bc7c66a82dd625462c064b673e588");
  });

  it("hashimoto-small", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(32);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 64 bytes per data, 4 entries in shard, 2 random access
    const kv = await MinabledKV.deploy(
      [6, 8, 2, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
    await kv.deployed();

    for (let i = 0; i < 16; i++) {
      await kv.put(ethers.utils.formatBytes32String(i.toString()), hexlify64(i));
    }

    let h0 = "0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5";
    let r0 = await kv.hashimoto(0, 0, h0, [padRight64(hexlify64(2)), padRight64(hexlify64(3))]);
    expect(r0).to.equal("0x7529f239daba33139d2125aa1c5a2ce73e2a31557e8dd97e2b468335f44b73a3");

    let r1 = await kv.hashimoto(0, 1, h0, [padRight64(hexlify64(2)), padRight64(hexlify64(1))]);
    expect(r1).to.equal("0x292fc526cfd06711a651ed8605488023d58e8206b869668b13eb7072e3847760");

    let r2 = await kv.hashimoto(0, 2, h0, [padRight64(hexlify64(10)), padRight64(hexlify64(0))]);
    expect(r2).to.equal("0x3ab8ce32981e789e67abf48d7753da99792bc7c66a82dd625462c064b673e588");

    let r3 = await kv.hashimoto(1, 1, h0, [padRight64(hexlify64(6)), padRight64(hexlify64(5))]);
    expect(r3).to.equal("0x292fc526cfd06711a651ed8605488023d58e8206b869668b13eb7072e3847760");
  });

  it("hashimoto-large", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(32);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 4096 bytes per data, 32 entries in shard, 16 random access
    const kv = await MinabledKV.deploy(
      [12, 17, 16, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
    await kv.deployed();

    let l = 0;
    let dataList = [];
    for (let i = 0; i < 32; i++) {
      let d = "0x";
      for (let j = 0; j < 4096 / 32; j++) {
        d = ethers.utils.hexConcat([d, ethers.utils.keccak256(hexlify4(l))]);
        l = l + 1;
      }
      dataList.push(d);
      await kv.put(ethers.utils.formatBytes32String(i.toString()), dataList[i]);
    }

    let h0 = "0x2cfe17dc69e953b28d77cdb7cdc86ce378dfe1e846f4be9cbe9dfb18efa5dfb5";
    let r0 = await kv.hashimoto(0, 0, h0, [
      dataList[10],
      dataList[9],
      dataList[13],
      dataList[4],
      dataList[24],
      dataList[2],
      dataList[9],
      dataList[24],
      dataList[4],
      dataList[25],
      dataList[27],
      dataList[4],
      dataList[3],
      dataList[23],
      dataList[21],
      dataList[11],
    ]);

    // await kv.hashimotoNonView(0, 0, h0, [
    //     dataList[10],
    //     dataList[9],
    // dataList[13],
    // dataList[4],
    // dataList[24],
    // dataList[2],
    // dataList[9],
    // dataList[24],
    // dataList[4],
    // dataList[25],
    // dataList[27],
    // dataList[4],
    // dataList[3],
    // dataList[23],
    // dataList[21],
    // dataList[11],
    // ]);
  });
});

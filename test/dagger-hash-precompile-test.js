const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require("crypto");

var ToBig = (x) => ethers.BigNumber.from(x);
var hexlify4 = (x) => ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 4);
const testKey = "0x0000000000000000000000000000000000000000000000000000000000000001"
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

    await kv.put(testKey, "0x11223344");
    expect(await kv.get(testKey, 0, 4)).to.equal(
      "0x11223344"
    );

    expect(await kv.checkDaggerHash(testKey, "0x11223344"))
      .to.be.true;
    
    expect(
      await kv.checkDaggerHashNormal(testKey, "0x11223344")
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

    await kv.put(testKey, d);
    expect(await kv.get(testKey, 0, 4096)).to.equal(d);

    expect(await kv.checkDaggerHash(testKey, d)).to.be
      .true;

    expect(await kv.checkDaggerHashNormal(testKey, d)).to
      .be.true;

    // Uncomment for gas report
    await kv.checkDaggerHashNonView(testKey, d);
    await kv.checkDaggerHashDirectNonView(testKey, d);
    await kv.checkDaggerHashNormalNonView(testKey, d);
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
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    const data = crypto.randomBytes(4096 * 2)
    const d = ethers.utils.hexlify(data);
    await kv.put(testKey, d);
    expect(await kv.get(testKey, 0, 8192)).to.equal(d);

    const root = await ml.merkleRoot(data, 4096, 1);
    const leftSliceProof = await ml.getProof(data,4096,1,0);
    const rightSliceProof = await ml.getProof(data,4096,1,1);
    // A direct merkle tree verify
    expect(await ml.verify(data.slice(0,4096), 0, root, leftSliceProof)).to.be.true;
    expect(await ml.verify(data.slice(4096,8192), 1, root, rightSliceProof)).to.be.true;
    // Via sysContract's method
    expect(await kv.checkDaggerHashNormalMerkle(0, testKey, leftSliceProof, data.slice(0,4096))).to
      .be.true;
    expect(await kv.checkDaggerHashNormalMerkle(1, testKey, rightSliceProof, data.slice(4096,4096*2))).to
      .be.true;
  });
});

const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const crypto = require("crypto");

describe("MerkleLib Test", function () {
  it("full zero data verify", async function () {
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    let data = new Array(64 * 8).fill(0);
    let root = await ml.merkleRoot(data, 64, 3);
    for (let i = 0; i < 8; i++) {
      let proof = await ml.getProof(data, 64, 3, i);
      let chunkData = data.slice(i * 64, (i + 1) * 64);
      expect(await ml.verify(chunkData, i, 3, root, proof)).to.equal(true);
    }
  });

  it("full random data verify", async function () {
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    let data = crypto.randomBytes(64 * 8);
    let root = await ml.merkleRoot(data, 64, 3);
    for (let i = 0; i < 8; i++) {
      let proof = await ml.getProof(data, 64, 3, i);
      let chunkData = data.slice(i * 64, (i + 1) * 64);
      expect(await ml.verify(chunkData, i, 3, root, proof)).to.equal(true);
    }
  });

  it("partial random data verify0", async function () {
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    let data = crypto.randomBytes(8);
    let root = await ml.merkleRoot(data, 64, 3);
    for (let i = 0; i < 8; i++) {
      let proof = await ml.getProof(data, 64, 3, i);
      let chunkData = data.slice(i * 64, (i + 1) * 64);
      if (chunkData.length == 0) {
        break;
      }
      expect(await ml.verify(chunkData, i, 3, root, proof)).to.equal(true);
    }
  });

  it("partial random data verify1", async function () {
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    let data = crypto.randomBytes(64 * 3 + 16);
    let root = await ml.merkleRoot(data, 64, 3);
    for (let i = 0; i < 8; i++) {
      let proof = await ml.getProof(data, 64, 3, i);
      let chunkData = data.slice(i * 64, (i + 1) * 64);
      if (chunkData.length == 0) {
        break;
      }
      expect(await ml.verify(chunkData, i, 3, root, proof)).to.equal(true);
    }
  });

  it("partial random data verify2", async function () {
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    let data = crypto.randomBytes(64 * 6 + 48);
    let root = await ml.merkleRoot(data, 64, 3);
    for (let i = 0; i < 8; i++) {
      let proof = await ml.getProof(data, 64, 3, i);
      let chunkData = data.slice(i * 64, (i + 1) * 64);
      if (chunkData.length == 0) {
        break;
      }
      expect(await ml.verify(chunkData, i, 3, root, proof)).to.equal(true);
    }
  });

  it("gas for 4K chunk and 32K kv", async function () {
    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();

    // await ml.merkleRootNoView(crypto.randomBytes(4096 * 8), 4096, 3);
    await ml.merkleRootNoView(crypto.randomBytes(4096), 4096, 3);
    await ml.merkleRootNoView(crypto.randomBytes(4096 * 2), 4096, 3);
    await ml.merkleRootNoView(crypto.randomBytes(4096 * 3), 4096, 3);

    await ml.keccak256NoView(crypto.randomBytes(4096 * 3));
  });
});

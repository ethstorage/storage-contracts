const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const  crypto  = require("crypto");
const { constants } = require("buffer");

var ToBig = (x) => ethers.BigNumber.from(x);
var padRight32 = (x) => x.padEnd(66, "0");
var padLeft32 = (x) => ethers.utils.hexZeroPad(x, 32);
var padRight64 = (x) => x.padEnd(130, "0");
var padLeft64 = (x) => ethers.utils.hexZeroPad(x, 64);
var hexlify64 = (x) => padLeft64(ethers.utils.hexlify(x));
var hexlify4 = (x) => ethers.utils.hexZeroPad(ethers.utils.hexlify(x), 4);
var formatB32Str = (x) => ethers.utils.formatBytes32String(x);
var keccak256 = (x) => ethers.utils.keccak256(x);
var concat = (x) => ethers.utils.concat(x);
var hexlen = (str) => ethers.utils.hexDataLength(str);

describe("Basic Func Test", function () {
  it("hashimoto-tiny", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(4096);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 64 bytes per data, 4 entries in shard, 1 random access
    const kv = await MinabledKV.deploy(
      [6, 6, 8, 1, 0, 60, 40, 1024, 0, sc.address],
      0,
      0,
      0,
      ethers.utils.formatBytes32String("")
    );
    await kv.deployed();

    // put 16 kv-datas 
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
    const sc = await SystemContract.deploy(4096);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 64 bytes per data, 4 entries in shard, 2 random access
    const kv = await MinabledKV.deploy(
      [6, 6, 8, 2, 0, 60, 40, 1024, 0, sc.address],
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
    const sc = await SystemContract.deploy(4096);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 4096 bytes per data, 32 entries in shard, 16 random access
    const kv = await MinabledKV.deploy(
      [12, 12, 17, 16, 0, 60, 40, 1024, 0, sc.address],
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
    expect(r0).to.equal("0xdc5ed7906841c9936f16b4fcb44e4320516d32a2c94b0166197ea021a6150a05");

    // await kv.hashimotoNonView(0, 0, h0, [
    //     dataList[10],
    // dataList[9],
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

  it("hashimoto-large-keccak", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(4096);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 4096 bytes per data, 32 entries in shard, 16 random access
    const kv = await MinabledKV.deploy(
      [12, 12, 17, 3, 0, 60, 40, 1024, 0, sc.address],
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

    await kv.hashimotoKeccak256NonView(0, 0, h0, [
      dataList[21],
      dataList[7],
      dataList[31],
      // dataList[24],
      // dataList[29],
      // dataList[7],
      // dataList[12],
      // dataList[4],
      // dataList[1],
      // dataList[30],
      // dataList[31],
      // dataList[16],
      // dataList[5],
      // dataList[19],
      // dataList[30],
      // dataList[13],
    ]);
  });

  it("calculateDiffAndInitHash", async function () {
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(4096);
    await sc.deployed();
    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
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

describe("Full cycle of mining procedure", function () {
  const maxKvSizeBits = 6;
  const chunkSizeBits = 6;
  const shardSizeBits = 10;
  const randomChecks = 1;
  const minimumDiff = 1;
  const targetIntervalSec = 60;
  const cutoff = 40;
  const diffAdjDivisor = 1024;
  const coinbaseShare = 0;
  // shardEntryBits is the number of KV included in the shard.  
  const shardEntryBits = shardSizeBits - maxKvSizeBits;
  const verbose = false;

  const LIMIT = 100;

  const local_idx_2_key = x => ethers.utils.formatBytes32String(x.toString());

  /* Conduct a off-chain pre-check for gaining reward purpose */
  async function hashimoto_local(startShardId, shardLenBits, _hash0, maskedData, randomList, kv, sc) {
    const maxKvSize = 1 << maxKvSizeBits;
    // shardLenBits means the number of chunk which engage in the mint-progress for miner to find a valid difficulty.
    const rows = 1 << (shardEntryBits + shardLenBits);
    let hash0 = _hash0;
    for (let i = 0; i < randomChecks; i++) {
        const parent = ethers.BigNumber.from(hash0).mod(rows).toNumber();
        const kvIdx = parent + (startShardId << shardEntryBits);
        /* Try not to use contract kvMap and idxMap, to reduce gas cost */
        /*
        const skey = await kv.idxMap(kvIdx);;
        const phy = await kv.kvMap(skey);
        const original_hash = ethers.utils.hexlify(ethers.BigNumber.from(phy.hash));
        const data_hash = padRight32(original_hash);
        const matched = await sc.checkDaggerData(kvIdx, data_hash, maskedData[i]);
        */
        // is it equal to check kvIdx == random_i, in this shard local data
        if (kvIdx != randomList[i]) {
          return [0, false];
        }
        hash0 = keccak256(concat([padRight32(ethers.utils.hexlify(hash0)), maskedData[i]]));
    }
    return [hash0, true];
  }

  function permutator(inputArr) {
    var results = [];
  
    function permute(arr, memo) {
      var cur, memo = memo || [];
  
      for (var i = 0; i < arr.length; i++) {
        cur = arr.splice(i, 1);
        if (arr.length === 0) {
          results.push(memo.concat(cur));
        }
        permute(arr.slice(), memo.concat(cur));
        arr.splice(i, 0, cur[0]);
      }
  
      return results;
    }
  
    return permute(inputArr);
  }

  function random_generator() {
    const numbers = Array((1 << (shardSizeBits - maxKvSizeBits))-1).fill().map((_, index) => index + 1);
    numbers.sort(() => Math.random() - 0.5);
    return numbers.slice(0,randomChecks);
  }

  it("runs full mining cycle small", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(4096);

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 64 bytes per data, 16 entries in shard, 4 random access
    const kv = await MinabledKV.deploy(
      [maxKvSizeBits, chunkSizeBits, shardSizeBits, randomChecks, minimumDiff, 
       targetIntervalSec, cutoff, diffAdjDivisor, coinbaseShare, sc.address],
      0, //startTime
      0, //storageCost
      0, // dcfFactor
      ethers.utils.formatBytes32String("") //genesisHash
    );
    await kv.deployed();

    /* Debug : check the meta at beginning */
    if(verbose){
      let mining_debug_last_shard = async function(str){
        const lastKvIdx = await kv.lastMinableShardIdx();
        const info = await kv.infos(lastKvIdx);
        console.log("Stage %s MiningInfo :",str);
        console.log(info);
      };
      mining_debug_last_shard("INIT");
    }
    let l = 0;
    let dataList = [];
    for (let i = 0; i < (1 << (shardSizeBits - maxKvSizeBits)); i++) {
      let d = "0x";
      for (let j = 0; j < (1<<maxKvSizeBits) / 32; j++) {
        d = ethers.utils.hexConcat([d, ethers.utils.keccak256(hexlify4(l))]);
        l = l + 1;
      }
      dataList.push(d);
      // PUT won't change the diff info
      await kv.put(local_idx_2_key(i), dataList[i]);
    }

    const mineTs = 120;
    kv.setTimestamp(240);
    const meta = await kv.calculateDiffAndInitHash(0,1,mineTs);
    const diff = meta.diff.toNumber();
    const nonce = 1;

    let count = 0;
    let maskedData = [];
    while (count < LIMIT)
    {
      if(verbose){
        console.log("Turn %d ", count);
      }
      const a = ethers.utils.hexlify(meta.hash0);
      const b = padLeft32(ethers.utils.hexlify(wallet.address));
      const c = padLeft32(ethers.utils.hexlify(ethers.BigNumber.from(mineTs)));
      const d = padLeft32(ethers.utils.hexlify(ethers.BigNumber.from(nonce)));
      const h0 = keccak256(ethers.utils.concat([a,b,c,d]));
      /* random fashion: ready hard to find */
      //const randomList = random_generator();
      const randomList = [count % (1 << (shardSizeBits - maxKvSizeBits))];
      let dataSlice = [];
      Array.from(randomList, x => dataSlice.push(dataList[x]));

      const ret = await hashimoto_local(0, 0, h0, dataSlice, randomList, kv, sc);
      const success = ret[1];
      if (success) {
        const ret_hash0 = ret[0];
        const numericalHash = ethers.BigNumber.from(ret_hash0);
        const dividend = ethers.BigNumber.from(2);
        const ratio = dividend.pow(256).sub(1).div(numericalHash).toNumber();
        if (ratio >= diff){
          // matched
          maskedData = dataSlice;
          break;
        }
      }
      // failed to search
      count = count + 1;
    }
    expect(LIMIT).to.be.above(count);

    await kv.mine(0,0,wallet.address,mineTs,nonce,[[]],maskedData);
    
  });
});

describe("Full cycle of mining procedure with Merkle proof", function () {
  const maxKvSizeBits = 13; // 4K x 2
  const chunkSizeBits = 12; // 4K
  const shardSizeBits = 14; // 2 blocks per shard
  const randomChecks = 1;
  const minimumDiff = 1;
  const targetIntervalSec = 60;
  const cutoff = 40;
  const diffAdjDivisor = 1024;
  const coinbaseShare = 0;
  const shardEntryBits = shardSizeBits - maxKvSizeBits;
  const verbose = false;

  const LIMIT = 10;

  const local_idx_2_key = x => ethers.utils.formatBytes32String(x.toString());

  /* Conduct a off-chain pre-check for gaining reward purpose */
  function hashimoto_local(startShardId, shardLenBits, _hash0, maskedData, randomList, chunkIdArray, chunkLenBits) {
    const maxKvSize = 1 << maxKvSizeBits;
    const rows = 1 << (shardEntryBits + shardLenBits + chunkLenBits);// shardNums * shardChunks *
    let hash0 = _hash0;
    for (let i = 0; i < randomChecks; i++) {
        const parent = ethers.BigNumber.from(hash0).mod(rows).toNumber();
        const sampleChunkIdx = parent + (startShardId << (shardEntryBits + chunkLenBits));
        const kvIdx = sampleChunkIdx >> chunkLenBits;
        const chunkLeafIdx = sampleChunkIdx % (1 << chunkLenBits);
        if (verbose){
          console.log("hash is "+hash0);
          console.log("kvIdx %d -- desired randomList idx %d; chunkIdx %d -- desired id from array %d ", 
                      kvIdx, randomList[i], chunkLeafIdx, chunkIdArray[i]);
        }
        // in shard local data, index matches = data matches
        if (kvIdx != randomList[i] || chunkLeafIdx != chunkIdArray[i]) {
          return [0, false];
        }
        hash0 = keccak256(concat([padRight32(ethers.utils.hexlify(hash0)), maskedData[i]]));
    }
    return [hash0, true];
  }

  function random_generator() {
    const numbers = Array((1 << (shardSizeBits - maxKvSizeBits))-1).fill().map((_, index) => index + 1);
    numbers.sort(() => Math.random() - 0.5);
    return numbers.slice(0,randomChecks);
  }

  it("test checkDaggerDataWithProof()",async function(){
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(2048);
    await sc.deployed();

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 32KB per KV block, 4 entries in shard, 1 random access
    const _chunkSizeBits = 11; // 2048
    const kv = await MinabledKV.deploy(
      [maxKvSizeBits, _chunkSizeBits, shardSizeBits, randomChecks, minimumDiff, 
       targetIntervalSec, cutoff, diffAdjDivisor, coinbaseShare, sc.address],
      0, //startTime
      0, //storageCost
      0, // dcfFactor
      ethers.utils.formatBytes32String("") //genesisHash
    );
    await kv.deployed();

    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();
    
    const numShards = 1 << (shardSizeBits - maxKvSizeBits);
    let l = 0;
    let dataList = [];

    const dataSize = 6000;
    // put a whole kvSize data 6000, the maxKvSize is 8192 , the chunkSize is 2048
    // chunk0 size = 2048 ; chunk1 size = 2048 ; chunk2 size =1904 ; chunk3 size = 0 
    const kvIdx_0 = 0 
    const d = crypto.randomBytes(dataSize);
    dataList.push(d);
    // PUT won't change the diff info
    await kv.put(local_idx_2_key(kvIdx_0), ethers.utils.hexlify(dataList[kvIdx_0]));

    const getData = await kv.get(local_idx_2_key(kvIdx_0),0,dataSize)
    const expectData = ToBig(dataList[kvIdx_0]).toHexString();
    expect(getData).to.eq(expectData);

    const kvInfo_0 = await kv.getKVInfo(kvIdx_0)
    
    const CHUNK_SIZE = (await kv.chunkSize()).toNumber();
    const chunkLenBits = (await kv.chunkLenBits()).toNumber();

    // sample chunk 0 
    const SAMPLE_CHUNK_0 = 0;
    const proof_0= await ml.getProof(dataList[kvIdx_0],CHUNK_SIZE,chunkLenBits,SAMPLE_CHUNK_0)
    let chunkData_0 = Buffer.alloc(CHUNK_SIZE)
    let startChunkPtr = 0
    dataList[kvIdx_0].copy(chunkData_0,0,startChunkPtr,CHUNK_SIZE);
    let result_0 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_0,kvInfo_0,proof_0,chunkData_0)
    expect(result_0).to.eq(true);

    // sample chunk 1
    const SAMPLE_CHUNK_1 = 1;
    const proof_1= await ml.getProof(dataList[kvIdx_0],CHUNK_SIZE,chunkLenBits,SAMPLE_CHUNK_1)
    let chunkData_1 = Buffer.alloc(CHUNK_SIZE,0)
    startChunkPtr = CHUNK_SIZE  + startChunkPtr
    dataList[kvIdx_0].copy(chunkData_1,0,startChunkPtr,startChunkPtr+CHUNK_SIZE);
    let result_1 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_1,kvInfo_0,proof_1,chunkData_1)
    expect(result_1).to.eq(true);

    // sample chunk 2 
    const SAMPLE_CHUNK_2 = 2;
    const proof_2 = await ml.getProof(dataList[kvIdx_0],CHUNK_SIZE,chunkLenBits,SAMPLE_CHUNK_2)
    let chunkData_2 = Buffer.alloc(CHUNK_SIZE,0)
    startChunkPtr += CHUNK_SIZE 
    dataList[kvIdx_0].copy(chunkData_2,0,startChunkPtr,startChunkPtr+1904);
    let result_2 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_2,kvInfo_0,proof_2,chunkData_2)
    expect(result_2).to.eq(true);

    //sample chunk 3 
    const SAMPLE_CHUNK_3 = 3;
    const proof_3= await ml.getProof(dataList[kvIdx_0],CHUNK_SIZE,chunkLenBits,SAMPLE_CHUNK_3)
    let chunkData_3 = Buffer.alloc(CHUNK_SIZE,0)
    let result_3 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_3,kvInfo_0,proof_3,chunkData_3)
    expect(result_3).to.eq(true);

    // sample chunk 4 
    {
      const SAMPLE_CHUNK_4 = 4;
      let chunkData_4 = Buffer.alloc(CHUNK_SIZE,0)
      let result_4 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_4,kvInfo_0,[],chunkData_4)
      expect(result_4).to.eq(true);
      let chunkData_4_fail = Buffer.alloc(CHUNK_SIZE,1)
      result_4 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_4,kvInfo_0,[],chunkData_4_fail)
      expect(result_4).to.eq(false);

    }


    // ======== put the kvIdx 1 ============= 
    // put a kvSize data 4096, the KvSize is 4096 , the chunkSize is 2048
    // chunk4 size = 2048 ; chunk5 size = 2048 ; chunk6 size =0 ; chunk7 size = 0 
    const datasize_1 = 4096
    const kvIdx_1 = 1 
    const d1 = crypto.randomBytes(datasize_1);
    dataList.push(d1);
    // PUT won't change the diff info
    await kv.put(local_idx_2_key(kvIdx_1), ethers.utils.hexlify(dataList[kvIdx_1]));

    const getData1 = await kv.get(local_idx_2_key(kvIdx_1),0,datasize_1)
    const expectData1 = ToBig(dataList[kvIdx_1]).toHexString();
    expect(getData1).to.eq(expectData1);

    const kvInfo_1 = await kv.getKVInfo(kvIdx_1)
    let chunksNumPerKV = 1 << chunkLenBits

    // sample ChunkIdx 4 
    const SAMPLE_CHUNK_4 = 4;
    let nChunkBits = datasize_1 / CHUNK_SIZE - 1;
    const proof_4= await ml.getProof(dataList[kvIdx_1],CHUNK_SIZE,nChunkBits,SAMPLE_CHUNK_4%chunksNumPerKV)
    let chunkData_4 = Buffer.alloc(CHUNK_SIZE,0)
    dataList[kvIdx_1].copy(chunkData_4,0,0,CHUNK_SIZE);
    let result_4 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_4,kvInfo_1,proof_4,chunkData_4)
    expect(result_4).to.eq(true);

    // sample ChunkIdx 5 
    const SAMPLE_CHUNK_5 = 5;
    const proof_5 = await ml.getProof(dataList[kvIdx_1],CHUNK_SIZE,nChunkBits,SAMPLE_CHUNK_5%chunksNumPerKV)
    const chunkData_5 = Buffer.alloc(CHUNK_SIZE,0);
    dataList[kvIdx_1].copy(chunkData_5,0,CHUNK_SIZE,2*CHUNK_SIZE);
    let result_5 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_5,kvInfo_1,proof_5,chunkData_5,)
    expect(result_5).to.eq(true);


    // sample ChunkIdx 6
    const SAMPLE_CHUNK_6 = 6;
    let chunkData_6 = Buffer.alloc(CHUNK_SIZE,0)
    let result_6 = await kv.checkDaggerDataWithProof(SAMPLE_CHUNK_6,kvInfo_1,[],chunkData_6)
    expect(result_6).to.eq(true);

  })

  it("runs full mining cycle 32KB", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    let wallet = ethers.Wallet.createRandom().connect(owner.provider);
    const SystemContract = await ethers.getContractFactory("TestSystemContractDaggerHashimoto");
    const sc = await SystemContract.deploy(4096);
    await sc.deployed();

    const MinabledKV = await ethers.getContractFactory("TestDecentralizedKVDaggerHashimoto");
    // 32KB per KV block, 4 entries in shard, 1 random access
    const kv = await MinabledKV.deploy(
      [maxKvSizeBits, chunkSizeBits, shardSizeBits, randomChecks, minimumDiff, 
       targetIntervalSec, cutoff, diffAdjDivisor, coinbaseShare, sc.address],
      0, //startTime
      0, //storageCost
      0, // dcfFactor
      ethers.utils.formatBytes32String("") //genesisHash
    );
    await kv.deployed();

    const MerkleLib = await ethers.getContractFactory("TestMerkleLib");
    const ml = await MerkleLib.deploy();
    await ml.deployed();
    
    const numShards = 1 << (shardSizeBits - maxKvSizeBits);
    let l = 0;
    let dataList = [];
    for (let i = 0; i < numShards; i++) {
      // 32KB data per KV block
      const d = crypto.randomBytes(1 << maxKvSizeBits);
      dataList.push(d);
      // PUT won't change the diff info
      await kv.put(local_idx_2_key(i), ethers.utils.hexlify(dataList[i]));
    }

    const mineTs = 120;
    kv.setTimestamp(240);
    const meta = await kv.calculateDiffAndInitHash(0,1,mineTs);
    const diff = meta.diff.toNumber();
    const nonce = 1;
    const CHUNK_SIZE = (await kv.chunkSize()).toNumber();
    const chunkLenBits = (await kv.chunkLenBits()).toNumber();
    if (verbose) console.log("chunkLenBits: " + chunkLenBits);

    let count = 0;
    let chunksIdxArrayPointer = 0;
    let maskedData = [];
    let chunkIdArray = [];
    let randomList = [];
    while (count < LIMIT)
    {
      if(verbose){
        console.log("Turn %d ", count);
      }
      const a = ethers.utils.hexlify(meta.hash0);
      const b = padLeft32(ethers.utils.hexlify(wallet.address));
      const c = padLeft32(ethers.utils.hexlify(ethers.BigNumber.from(mineTs)));
      const d = padLeft32(ethers.utils.hexlify(ethers.BigNumber.from(nonce)));
      const h0 = keccak256(ethers.utils.concat([a,b,c,d]));

      /* random fashion: ready hard to find */
      //const randomList = random_generator();
      randomList = [count % numShards];
      let dataSlice = [];
      Array.from(randomList, x => 
          dataSlice.push(dataList[x].slice(chunksIdxArrayPointer*CHUNK_SIZE,(chunksIdxArrayPointer+1)*CHUNK_SIZE)));
      chunkIdArray=[chunksIdxArrayPointer];
      
      const ret = hashimoto_local(0, 0, h0, dataSlice, randomList, chunkIdArray, chunkLenBits);
      const success = ret[1];
      if (success) {
        const ret_hash0 = ret[0];
        const numericalHash = ethers.BigNumber.from(ret_hash0);
        const dividend = ethers.BigNumber.from(2);
        const ratio = dividend.pow(256).sub(1).div(numericalHash).toNumber();
        if (ratio >= diff){
          // matched
          maskedData = dataSlice;
          break;
        }
      }
      // failed to search
      // increase the offset inside a KV block
      chunksIdxArrayPointer = (chunksIdxArrayPointer+1) % (1 << chunkLenBits);
      // examine all chunks inside a KV block before move to next shards 
      if (0 == chunksIdxArrayPointer) count = count + 1;
    }
    expect(LIMIT).to.be.above(count);

    /* Up to here, we get a valid maskedData and chunkArray, construct proofs here */
    let proofsDim2 = [];
    for (let i = 0; i < randomChecks; i++) {
      const data = dataList[randomList[i]];
      const chunkIdx = chunkIdArray[i];
      const proof = await ml.getProof(data, CHUNK_SIZE, chunkLenBits, chunkIdx);
      proofsDim2.push(proof);
    }

    await kv.mine(0,0,wallet.address,mineTs,nonce,proofsDim2,maskedData);
    
  });
});

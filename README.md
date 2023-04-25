# EthStorage Decentralized Storage Contracts

## Install
```sh
npm install
```
## Provide RPC URL and private key in .env
```sh

PRIVATE_KEY=0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1
RPC_URL=http://127.0.0.1:8545
```
## Deploy
```sh
npx hardhat run scripts/deploy.js --network dev
```
## Init shard
```sh
npx hardhat run scripts/initShard.js --network dev
``` 

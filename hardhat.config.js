require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');
let { rpc, ftmscanApi, privateKey } = require("./secrets.json");

module.exports = {
  solidity: "0.8.0",
  networks: {
    hardhat: {
      forking: {
        url: rpc,
        timeout: 200000
      }
    },
    ftm: {
      url: rpc,
      accounts: [privateKey]
    }
  },
  etherscan: {
    apiKey: ftmscanApi
  }
};
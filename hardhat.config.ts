require("dotenv").config();
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-verify";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
import 'hardhat-dependency-compiler';

const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY as string;
const MANAGER_PRIVATE_KEY = process.env.MANAGER_PRIVATE_KEY as string;
const MAINNET_DEPLOYER_PRIVATE_KEY = process.env.MAINNET_DEPLOYER_PRIVATE_KEY as string;

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
    },
    manager: {
      default: 1,
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.6.10",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.8.17",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.8.26",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    ],
  },
  dependencyCompiler: {
    paths: ["@chainlink/contracts-ccip/src/v0.8/shared/token/ERC677/BurnMintERC677.sol"],
  },
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
  },
  networks: {
    baseSepolia: {
      chainId: 84532,
      url: process.env.BASE_SEPOLIA_URL,
      accounts: [DEPLOYER_PRIVATE_KEY, MANAGER_PRIVATE_KEY],
    },
    base: {
      chainId: 8453,
      url: process.env.BASE_URL,
      accounts: [MAINNET_DEPLOYER_PRIVATE_KEY, MANAGER_PRIVATE_KEY],
    },
    sepolia: {
      chainId: 11155111,
      url: process.env.SEPOLIA_URL,
      accounts: [DEPLOYER_PRIVATE_KEY, MANAGER_PRIVATE_KEY],
    },
    mainnet: {
      chainId: 1,
      url: process.env.MAINNET_URL,
      accounts: [MAINNET_DEPLOYER_PRIVATE_KEY, MANAGER_PRIVATE_KEY],
    }
  },
  etherscan: {
    apiKey: {
        baseSepolia: process.env.BASESCAN_API_KEY,
        base: process.env.BASESCAN_API_KEY,
        sepolia: process.env.ETHERSCAN_API_KEY,
        mainnet: process.env.ETHERSCAN_API_KEY,
    }
  }
};

export default config;

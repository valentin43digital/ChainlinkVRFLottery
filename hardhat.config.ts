import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import 'hardhat-contract-sizer';
import 'hardhat-gas-reporter';
import "solidity-coverage";

dotenv.config();

// Ensure everything is in place
let DEPLOYER_MNEMONIC: string;
if (!process.env.DEPLOYER_MNEMONIC) {
  	throw new Error('Please set your DEPLOYER_MNEMONIC in the .env file')
} else {
  	DEPLOYER_MNEMONIC = process.env.DEPLOYER_MNEMONIC;
}
let ETHERSCAN_API_KEY: string;
if (!process.env.ETHERSCAN_API_KEY) {
  throw new Error('Please set your ETHERSCAN_API_KEY in the .env file')
} else {
	ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
}

let mainnetForkingSetting = {
	url: `https://bsc-dataseed.binance.org/`,
	blockNumber: 30159063
};

let testnetForkingSetting = {
	url: "https://data-seed-prebsc-1-s1.binance.org:8545",
};

const config: HardhatUserConfig = {
  	solidity: {
		compilers: [
				{
					version: '0.8.19',
					settings: {
						viaIR: true,
						optimizer: {
							enabled: true,
							runs: 1337
						}
					}
				},
				{
					version: '0.4.11'
				}
			]
	},
	networks: {
		hardhat: {
            forking: testnetForkingSetting
        },
		bsc_testnet: {
			url: "https://data-seed-prebsc-1-s1.binance.org:8545",
			chainId: 97,
			gasPrice: "auto",
			accounts: { mnemonic: DEPLOYER_MNEMONIC }
		},
		bsc_mainnet: {
			url: "https://bsc-dataseed.binance.org/",
			chainId: 56,
			gasPrice: "auto",
			accounts: { mnemonic: DEPLOYER_MNEMONIC }
		}
	},
	etherscan: {
			apiKey: ETHERSCAN_API_KEY
	},
	mocha: {
			grep: '^(?!.*; using Ganache).*'
	},
	contractSizer: {
			alphaSort: true,
			runOnCompile: true,
			disambiguatePaths: false,
	},
	gasReporter: {
		enabled: true
	}
};

export default config;
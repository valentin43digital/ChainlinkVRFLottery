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
let DEPLOYER_PRIVATE_KEY: string;
if (!process.env.DEPLOYER_PRIVATE_KEY) {
  	throw new Error('Please set your DEPLOYER_PRIVATE_KEY in the .env file')
} else {
  	DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;
}
let ETHERSCAN_API_KEY: string;
if (!process.env.ETHERSCAN_API_KEY) {
  throw new Error('Please set your ETHERSCAN_API_KEY in the .env file')
} else {
	ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
}

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
            forking: {
                url: `https://bsc-dataseed.binance.org/`,
                blockNumber: 28318015
            }
        },
		bsc_testnet: {
			url: "https://data-seed-prebsc-1-s1.binance.org:8545",
			chainId: 97,
			gasPrice: "auto",
			accounts: [ `0x${DEPLOYER_PRIVATE_KEY}` ]
		},
		bsc_mainnet: {
			url: "https://bsc-dataseed.binance.org/",
			chainId: 56,
			gasPrice: "auto",
			accounts: [ `0x${DEPLOYER_PRIVATE_KEY}` ]
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
	}
};

export default config;
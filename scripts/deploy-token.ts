import hre, { ethers } from 'hardhat';
import fs from 'fs';
import dotenv from 'dotenv';

async function main () {
	const net = hre.network.name;

	const config = dotenv.parse(fs.readFileSync(`.env-${net}`));
	for (const parameter in config) {
		process.env[parameter] = config[parameter];
	}

    const ConsumerConfig = {
        subscriptionId: 2937,
        callbackGasLimit: 2_500_000,
        requestConfirmations: 3,
        gasPriceKey: "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314"
    }

    const ProtocolConfig = {
        holderLotteryPrizePoolAddress:  config.HODL_POOL,
        firstBuyLotteryPrizePoolAddress:  config.JACKPOT_POOL,
        donationLotteryPrizePoolAddress:  config.DONATION_POOL,
        devFundWalletAddress: config.DEV,
        treasuryAddress: config.TREASURY,
        burnFee: 50,
        liquidityFee: 75,
        distributionFee: 50,
        treasuryFee: 50,
        devFee: 75,
        firstBuyLotteryPrizeFee: 50,
        holdersLotteryPrizeFee: 75,
        donationLotteryPrizeFee: 75
    }

    const LotteryConfig = {
        firstBuyLotteryEnabled: true,
        holdersLotteryEnabled: true,
        holdersLotteryTxTrigger: 5,
        holdersLotteryMinBalance: ethers.utils.parseEther("10000"),
        donationAddress: config.DONATE_TO,
        donationsLotteryEnabled: true,
        minimumDonationEntries: 2,
        donationLotteryTxTrigger: 5,
        minimalDonation: ethers.utils.parseEther("1000")
    }

    const LotteryTokenFactory = await ethers.getContractFactory("LotteryToken")
    const token = await LotteryTokenFactory.deploy(
        config.MINT_TO,
        config.VRF_COORDINATOR_ADDRESS,
        config.PANCAKE_ROUTER_ADDRESS,
        ConsumerConfig,
        ProtocolConfig,
        LotteryConfig
    )

	// Sync env file
	fs.appendFileSync(
		`.env-${net}`,
		`LOTTERY_TOKEN_ADDRESS=${token.address}\r`
	);
	console.log(`Lottery Token: ${token.address}`);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
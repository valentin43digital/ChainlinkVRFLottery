import hre, { ethers } from 'hardhat';
import fs from 'fs';
import dotenv from 'dotenv';

async function main() {
    const net = hre.network.name;

    const config = dotenv.parse(fs.readFileSync(`.env-${net}`));
    for (const parameter in config) {
        process.env[parameter] = config[parameter];
    }

    const ConsumerConfig = {
        subscriptionId: 3227, // TODO: use real value for mainnet
        callbackGasLimit: 2_500_000, // TODO: use real value for mainnet
        requestConfirmations: 3, // TODO: use real value for mainnet
        gasPriceKey: "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314" // TODO: use real value for mainnet
    }

    const ProtocolConfig = {
        holderLotteryPrizePoolAddress: config.HODL_POOL,
        smashTimeLotteryPrizePoolAddress: config.JACKPOT_POOL,
        donationLotteryPrizePoolAddress: config.DONATION_POOL,
        teamAddress: config.DEV,
        treasuryAddress: config.TREASURY,
        teamFeesAccumulationAddress: config.TEAM_ACCUMULATION,
        treasuryFeesAccumulationAddress: config.TREASURY_ACCUMULATION,
        burnFee: 1000,
        liquidityFee: 1500,
        distributionFee: 1000,
        treasuryFee: 1000,
        devFee: 1500,
        smashTimeLotteryPrizeFee: 1000,
        holdersLotteryPrizeFee: 1500,
        donationLotteryPrizeFee: 1500
    }

    const LotteryConfig = {
        smashTimeLotteryEnabled: false,
        smashTimeLotteryConversionThreshold: ethers.utils.parseEther("10"),
        holdersLotteryEnabled: true,
        holdersLotteryTxTrigger: 20, // TODO: use real value for mainnet
        holdersLotteryMinPercent: 1, // TODO: use real value for mainnet
        donationsLotteryEnabled: true,
        minimumDonationEntries: 2, // TODO: use real value for mainnet
        minimalDonation: ethers.utils.parseEther("1000"),
        donationConversionThreshold: ethers.utils.parseEther("1000"),
    }

    const LotteryTokenFactory = await ethers.getContractFactory("LayerZ")
    const token = await LotteryTokenFactory.deploy(
        config.MINT_TO,
        config.VRF_COORDINATOR_ADDRESS,
        config.PANCAKE_ROUTER_ADDRESS,
        config.WBNB_ADDRESS,
        400, // TODO: use real value for mainnet
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

const ROUTER_ADDRESS = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
const COORDINATOR_ADDRESS = "0x6A2AAd07396B36Fe02a22b33cf443582f682c82f";
const MINT_TO = "0x31a7c42EDBc1eA0196aFa766a46b42B99a903e4e";
const ConsumerConfig = {
    subscriptionId: 0,
    callbackGasLimit: 2_500_000,
    requestConfirmations: 3,
    gasPriceKey: "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314"
}

const ProtocolConfig = {
    holderLotteryPrizePoolAddress:  MINT_TO,
    firstBuyLotteryPrizePoolAddress:  MINT_TO,
    donationLotteryPrizePoolAddress:  MINT_TO,
    devFundWalletAddress: MINT_TO,
    treasuryAddress: MINT_TO,
    burnFee: 75,
    liquidityFee: 75,
    distributionFee: 50,
    treasuryFee: 75,
    devFee: 50,
    firstBuyLotteryPrizeFee: 75,
    holdersLotteryPrizeFee: 75,
    donationLotteryPrizeFee: 50
}

const LotteryConfig = {
    firstBuyLotteryEnabled: true,
    holdersLotteryEnabled: true,
    holdersLotteryTxTrigger: 5,
    holdersLotteryMinBalance: "10000000000000000000000",
    donationAddress: MINT_TO,
    donationsLotteryEnabled: true,
    minimumDonationEntries: 2,
    donationLotteryTxTrigger: 5,
    minimalDonation: "1000000000000000000000"
}



module.exports = [
    MINT_TO,
    COORDINATOR_ADDRESS,
    ROUTER_ADDRESS,
    ConsumerConfig,
    ProtocolConfig,
    LotteryConfig
]
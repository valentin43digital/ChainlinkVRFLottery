const ROUTER_ADDRESS = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const COORDINATOR_ADDRESS = "0xc587d9053cd1118f25F645F9E08BB98c9712A4EE";
const MINT_TO = "0xb331ED7dc039Ee25ab9acf9D1F665E9400fc3fD1";
const DONATE_TO = "0x5cf496C69BBEe8a9beB05B17Aa01e759487F71A3";
const DEV = "0x5B81163707dEb08e0C7Ec4344E3FEF8AE6694b25";
const TREASURY = "0x7fb1850DAA5A020724f038f78f5ACE91Cf0789Cf";
const JACKPOT_POOL = "0x0d49e6dd64e0b7d0F216c0Ae0ffa0E07800d8734";
const DONATION_POOL = "0xf45d91b91Eb193157FaDD79B76831E18F8a9D511";
const HODL_POOL = "0x14Bf6B5b1b25e8bd94e5c59Df8b557156D38e5dD";
const TEAM_ACCUMULATION = "0xEEd4E32c9BdA4d03fb140e4860a0f91111991054";
const TREASURY_ACCUMULATION = "0x6d30Cd5e292e226bEfd2d0673A4B67f0Db2D5661";
const WBNB_ADDRESS = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
const USDT_ADDRESS = "0x55d398326f99059fF775485246999027B3197955";

const ConsumerConfig = {
  subscriptionId: 969,
  callbackGasLimit: 2_500_000,
  requestConfirmations: 3,
  gasPriceKey:
    "0xba6e730de88d94a5510ae6613898bfb0c3de5d16e609c5b7da808747125506f7", // 500 gwei
};

const ProtocolConfig = {
  holderLotteryPrizePoolAddress: HODL_POOL,
  smashTimeLotteryPrizePoolAddress: JACKPOT_POOL,
  donationLotteryPrizePoolAddress: DONATION_POOL,
  teamAddress: DEV,
  treasuryAddress: TREASURY,
  teamFeesAccumulationAddress: TEAM_ACCUMULATION,
  treasuryFeesAccumulationAddress: TREASURY_ACCUMULATION,
  burnFee: 1000,
  liquidityFee: 1500,
  distributionFee: 1000,
  treasuryFee: 1000,
  devFee: 1500,
  smashTimeLotteryPrizeFee: 1000,
  holdersLotteryPrizeFee: 1500,
  donationLotteryPrizeFee: 1500,
};

const LotteryConfig = {
  smashTimeLotteryEnabled: true,
  smashTimeLotteryConversionThreshold: "1000000000000000000000",
  smashTimeLotteryTriggerThreshold: 1, // TODO: use real value for mainnet
  holdersLotteryEnabled: true,
  holdersLotteryTxTrigger: 5,
  holdersLotteryMinPercent: 1,
  donationAddress: DONATE_TO,
  donationsLotteryEnabled: true,
  minimumDonationEntries: 3,
  minimalDonation: "10000000000000000000000",
  donationConversionThreshold: "1000000000000000000000",
};

module.exports = [
  MINT_TO,
  COORDINATOR_ADDRESS,
  ROUTER_ADDRESS,
  WBNB_ADDRESS,
  USDT_ADDRESS,
  200,
  ConsumerConfig,
  ProtocolConfig,
  LotteryConfig,
];

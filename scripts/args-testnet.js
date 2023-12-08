const ROUTER_ADDRESS = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
const COORDINATOR_ADDRESS = "0x6A2AAd07396B36Fe02a22b33cf443582f682c82f";
const MINT_TO = "0xb331ED7dc039Ee25ab9acf9D1F665E9400fc3fD1";
const DONATE_TO = "0x5cf496C69BBEe8a9beB05B17Aa01e759487F71A3";
const DEV = "0x5B81163707dEb08e0C7Ec4344E3FEF8AE6694b25";
const TREASURY = "0x7fb1850DAA5A020724f038f78f5ACE91Cf0789Cf";
const JACKPOT_POOL = "0x0d49e6dd64e0b7d0F216c0Ae0ffa0E07800d8734";
const DONATION_POOL = "0xf45d91b91Eb193157FaDD79B76831E18F8a9D511";
const HODL_POOL = "0x14Bf6B5b1b25e8bd94e5c59Df8b557156D38e5dD";
const TEAM_ACCUMULATION = "0xEEd4E32c9BdA4d03fb140e4860a0f91111991054";
const TREASURY_ACCUMULATION = "0x6d30Cd5e292e226bEfd2d0673A4B67f0Db2D5661";
const WBNB_ADDRESS = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
const USDT_ADDRESS = "0xc515Df5D4a97Efc3f2adb1c95929da061A606Ac2";

const ConsumerConfig = {
  subscriptionId: 3227,
  callbackGasLimit: 2_500_000,
  requestConfirmations: 3,
  gasPriceKey:
    "0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314",
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
  smashTimeLotteryEnabled: false, // TODO: use real value
  smashTimeLotteryConversionThreshold: "1000000000000000000000",
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
  400,
  ConsumerConfig,
  ProtocolConfig,
  LotteryConfig,
];

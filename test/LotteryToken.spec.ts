import { expect } from 'chai';
import hre, { ethers } from 'hardhat'
import * as evm from './utils/evm'; 
import {
    LotteryToken,
    IPancakeFactory,
    IPancakeRouter02,
    VRFCoordinatorV2Interface,
    IPegSwap,
    IERC20,
    LinkToken
} from '../typechain-types';

import {
    VRF_COORDINATOR_ADDRESS,
    PANCAKE_FACTORY_ADDRESS,
    PANCAKE_ROUTER_ADDRESS,
    LINK_ADDRESS,
    WBNB_ADDRESS,
    PEG_LINK_ADDRESS,
    PEG_SWAP_ADDRESS
} from "./utils/constants";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { ConsumerConfigStruct, DistributionConfigStruct, LotteryConfigStruct } from '../typechain-types/contracts/LotteryToken';

describe("Lottery Token tests", () => {
    let pancakeFactory : IPancakeFactory;
    let pancakeRouter : IPancakeRouter02;
    let pegSwap : IPegSwap;
    let vrfCoordinator : VRFCoordinatorV2Interface;
    let token : LotteryToken;
    let link : LinkToken,
    peg_link : IERC20;
    let admin : SignerWithAddress,
        mephala : SignerWithAddress,
        orrin : SignerWithAddress,
        rion : SignerWithAddress,
        oracle : SignerWithAddress,
        donationRecipient : SignerWithAddress,
        holderLotteryPrizePool : SignerWithAddress,
        smashTimeLotteryPrizePool : SignerWithAddress,
        donationLotteryPrizePool : SignerWithAddress,
        team : SignerWithAddress,
        teamAccumlation : SignerWithAddress,
        treasury : SignerWithAddress,
        treasuryAccumulation : SignerWithAddress

    before( async () => {
        [
            admin,
            mephala,
            orrin,
            rion,
            oracle,
            donationRecipient,
            holderLotteryPrizePool,
            smashTimeLotteryPrizePool,
            donationLotteryPrizePool,
            team,
            teamAccumlation,
            treasury,
            treasuryAccumulation
        ] = await ethers.getSigners();

        pancakeFactory = await ethers.getContractAt("IPancakeFactory", PANCAKE_FACTORY_ADDRESS);
        pancakeRouter = await ethers.getContractAt("IPancakeRouter02", PANCAKE_ROUTER_ADDRESS);
        pegSwap = await ethers.getContractAt("IPegSwap", PEG_SWAP_ADDRESS)
        vrfCoordinator = await ethers.getContractAt("VRFCoordinatorV2Interface", VRF_COORDINATOR_ADDRESS);
        
        const ConsumerConfig : ConsumerConfigStruct = {
            subscriptionId: 0,
            callbackGasLimit: 2_500_000,
            requestConfirmations: 3,
            gasPriceKey: "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15"
        }
        const DistributionConfig : DistributionConfigStruct = {
            holderLotteryPrizePoolAddress:  holderLotteryPrizePool.address,
            smashTimeLotteryPrizePoolAddress:  smashTimeLotteryPrizePool.address,
            donationLotteryPrizePoolAddress:  donationLotteryPrizePool.address,
            teamAddress: team.address,
            treasuryAddress: treasury.address,
            teamFeesAccumulationAddress: teamAccumlation.address,
            treasuryFeesAccumulationAddress: treasuryAccumulation.address,
            burnFee: 1000,
            liquidityFee: 1500,
            distributionFee: 1000,
            treasuryFee: 1000,
            devFee: 1500,
            smashTimeLotteryPrizeFee: 1000,
            holdersLotteryPrizeFee: 1500,
            donationLotteryPrizeFee: 1500
        }
        const LotteryConfig : LotteryConfigStruct = {
            smashTimeLotteryEnabled: true,
            holdersLotteryEnabled: true,
            holdersLotteryTxTrigger: 6,
            holdersLotteryMinPercent: 1,
            donationAddress: donationRecipient.address,
            donationsLotteryEnabled: true,
            minimumDonationEntries: 2,
            donationLotteryTxTrigger: 5,
            minimalDonation: ethers.utils.parseEther("1000"),
        }
        const LotteryTokenFactory = await ethers.getContractFactory("LayerZ");

        token = await LotteryTokenFactory.deploy(
            admin.address,
            vrfCoordinator.address,
            pancakeRouter.address,
            400,
            ConsumerConfig,
            DistributionConfig,
            LotteryConfig
            );
            
        console.log(
            DistributionConfig.burnFee +
            DistributionConfig.liquidityFee +
            DistributionConfig.distributionFee +
            DistributionConfig.treasuryFee +
            DistributionConfig.devFee +
            DistributionConfig.smashTimeLotteryPrizeFee +
            DistributionConfig.holdersLotteryPrizeFee +
            DistributionConfig.donationLotteryPrizeFee
        );
        await evm.evm_increaseTime(60*60*24*30*6)
        console.log(await token.burnFeePercent());
        console.log(await token.liquidityFeePercent());
        console.log(await token.distributionFeePercent());
        console.log(await token.treasuryFeePercent());
        console.log(await token.devFeePercent());
        console.log(await token.smashTimeLotteryPrizeFeePercent());
        console.log(await token.holdersLotteryPrizeFeePercent());
        console.log(await token.donationLotteryPrizeFeePercent());
        link = await ethers.getContractAt("LinkToken", LINK_ADDRESS)
        peg_link = await ethers.getContractAt("IERC20", PEG_LINK_ADDRESS)

        await pancakeRouter.swapExactETHForTokens(
            ethers.utils.parseEther("1"),
            [
                WBNB_ADDRESS,
                PEG_LINK_ADDRESS
            ],
            admin.address,
            ethers.constants.MaxUint256,
            { value: ethers.utils.parseEther("1")}
        )

        await peg_link.approve(pegSwap.address, ethers.constants.MaxUint256)

        await pegSwap.swap(
            await peg_link.balanceOf(admin.address),
            peg_link.address,
            link.address
        )

        const subscriptionTx = await vrfCoordinator.createSubscription();
        const subscriptionReceipt = await subscriptionTx.wait();
        const subscriptionId = BigNumber.from(subscriptionReceipt.logs[0].topics[1]);
        const subscriptionIdOwner = "0x" + subscriptionReceipt.logs[0].data.slice(26, 66);
        // // console.log(subscriptionId, subscriptionIdOwner);
        await vrfCoordinator.addConsumer(subscriptionId, token.address)
        await link.transferAndCall(
            vrfCoordinator.address,
            await link.balanceOf(admin.address),
            ethers.utils.defaultAbiCoder.encode(["uint64"], [subscriptionId])
        )
        await token.setSubscriptionId(subscriptionId);

        await token.approve(pancakeRouter.address, ethers.constants.MaxUint256)
        
        await pancakeRouter.addLiquidityETH(
            token.address,
            ethers.utils.parseEther("10000000000").div(100).mul(85),
            0,
            0,
            admin.address,
            ethers.constants.MaxUint256,
            {value: ethers.utils.parseEther("1000")}
        )

        await token.transfer(smashTimeLotteryPrizePool.address, ethers.utils.parseEther("10000000000").div(100).mul(5));

        // console.log(await token.balanceOf(admin.address))
        // console.log(await token.balanceOf(smashTimeLotteryPrizePool.address))
        // console.log(await token.balanceOf(await pancakeFactory.getPair(token.address, WBNB_ADDRESS)))
    })

    it ("First Buy Lottery", async () => {
        console.log('START');
        console.log(team.address)
        console.log(treasury.address)
        console.log(token.address)
        await pancakeRouter.connect(rion).swapExactETHForTokens(
            0,
            [
                WBNB_ADDRESS,
                token.address
            ],
            rion.address,
            ethers.constants.MaxUint256,
            {value: ethers.utils.parseEther("100")}
        )

        console.log(await token.holdersLotteryTickets())
        // console.log(await token.balanceOf(token.address), "LIQUIDITY BALANCE")
        // console.log(await token.rounds("0xb7b10297a278d5822fd6fec5277df16de3178518dbdc9e995c1504b42ebef9d5"))
        await token.connect(smashTimeLotteryPrizePool).transfer(admin.address, BigNumber.from("375049233832347910968733749"))
        console.log(await token.holdersLotteryTickets())
        const tx =await token.rawFulfillRandomWords(
            BigNumber.from("0xb7b10297a278d5822fd6fec5277df16de3178518dbdc9e995c1504b42ebef9d5"),
            [0, 0],
        )
        // console.log(await token.balanceOf(token.address), "LIQUIDITY BALANCE")
        // console.log((await tx.wait()).gasUsed)
        // console.log(await token.rounds("0xb7b10297a278d5822fd6fec5277df16de3178518dbdc9e995c1504b42ebef9d5"))
    })
    it ("Holders Lottery", async () => {
        await token.transfer(mephala.address, ethers.utils.parseEther("1000000"))
        console.log(await token.holdersLotteryTickets())
        await token.transfer(orrin.address, ethers.utils.parseEther("1000000"))
        console.log(await token.holdersLotteryTickets())
        await token.connect(mephala).transfer(orrin.address, ethers.utils.parseEther("1000000"))
        console.log(await token.holdersLotteryTickets())
        await token.connect(orrin).transfer(mephala.address, ethers.utils.parseEther("1000000"))
        console.log(await token.holdersLotteryTickets())
        // console.log(await token.rounds("0x51f3dfe36b59e070617d445b9a6dcd11ecdd4fbf7be441290be0e2854b08171e"))
        const tx =await token.rawFulfillRandomWords(
            BigNumber.from("0x51f3dfe36b59e070617d445b9a6dcd11ecdd4fbf7be441290be0e2854b08171e"),
            [2],
        )
        // console.log(await token.balanceOf(token.address), "LIQUIDITY BALANCE")
        // console.log((await tx.wait()).gasUsed)
        // console.log(rion.address, orrin.address, mephala.address)
        // console.log(await token.rounds("0x51f3dfe36b59e070617d445b9a6dcd11ecdd4fbf7be441290be0e2854b08171e"))
     })
    it ("Donation Lottery", async () => {
        // console.log(await token.balanceOf(token.address), "LIQUIDITY BALANCE")
        await token.connect(mephala).transfer(donationRecipient.address, ethers.utils.parseEther("1000"))
        console.log(await token.holdersLotteryTickets())
        await token.connect(orrin).transfer(donationRecipient.address, ethers.utils.parseEther("1000"))
        console.log(await token.holdersLotteryTickets())
        // console.log(await token.rounds("0x5f37632b8819ea804e42c59eca4233994614f37c759602d6274b4415f2ba6182"))
        const tx =await token.rawFulfillRandomWords(
            BigNumber.from("0x5f37632b8819ea804e42c59eca4233994614f37c759602d6274b4415f2ba6182"),
            [2],
        )
        // console.log((await tx.wait()).gasUsed)
        // console.log(await token.balanceOf(token.address), "LIQUIDITY BALANCE")
        // console.log(rion.address, orrin.address, mephala.address)
        // console.log(await token.rounds("0x5f37632b8819ea804e42c59eca4233994614f37c759602d6274b4415f2ba6182"))
    })
    
})
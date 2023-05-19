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
        firstBuyLotteryPrizePool : SignerWithAddress,
        donationLotteryPrizePool : SignerWithAddress,
        devFundWallet : SignerWithAddress,
        treasury : SignerWithAddress

    before( async () => {
        [
            admin,
            mephala,
            orrin,
            rion,
            oracle,
            donationRecipient,
            holderLotteryPrizePool,
            firstBuyLotteryPrizePool,
            donationLotteryPrizePool,
            devFundWallet,
            treasury
        ] = await ethers.getSigners();

        pancakeFactory = await ethers.getContractAt("IPancakeFactory", PANCAKE_FACTORY_ADDRESS);
        pancakeRouter = await ethers.getContractAt("IPancakeRouter02", PANCAKE_ROUTER_ADDRESS);
        pegSwap = await ethers.getContractAt("IPegSwap", PEG_SWAP_ADDRESS)
        vrfCoordinator = await ethers.getContractAt("VRFCoordinatorV2Interface", VRF_COORDINATOR_ADDRESS);
        
        const ConsumerConfig : ConsumerConfigStruct = {
            subscriptionId: 0,
            callbackGasLimit: 2_500_000,
            requestConfirmations: 3,
            gasPriceKey: "0xba6e730de88d94a5510ae6613898bfb0c3de5d16e609c5b7da808747125506f7"
        }
        const DistributionConfig : DistributionConfigStruct = {
            holderLotteryPrizePoolAddress:  holderLotteryPrizePool.address,
            firstBuyLotteryPrizePoolAddress:  firstBuyLotteryPrizePool.address,
            donationLotteryPrizePoolAddress:  donationLotteryPrizePool.address,
            devFundWalletAddress: devFundWallet.address,
            treasuryAddress: treasury.address,
            burnFee: 75,
            liquidityFee: 75,
            distributionFee: 50,
            treasuryFee: 75,
            devFee: 50,
            firstBuyLotteryPrizeFee: 75,
            holdersLotteryPrizeFee: 75,
            donationLotteryPrizeFee: 50
        }
        const LotteryConfig : LotteryConfigStruct = {
            firstBuyLotteryEnabled: true,
            holdersLotteryEnabled: true,
            holdersLotteryTxTrigger: 5,
            holdersLotteryMinBalance: ethers.utils.parseEther("1000000"),
            donationAddress: donationRecipient.address,
            donationsLotteryEnabled: true,
            minimumDonationEntries: 2,
            donationLotteryTxTrigger: 5,
            minimalDonation: ethers.utils.parseEther("1000"),
        }
        const LotteryTokenFactory = await ethers.getContractFactory("LotteryToken");
        token = await LotteryTokenFactory.deploy(
            admin.address,
            vrfCoordinator.address,
            pancakeRouter.address,
            ConsumerConfig,
            DistributionConfig,
            LotteryConfig
        );

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
        // console.log(subscriptionId, subscriptionIdOwner);
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

        await token.transfer(firstBuyLotteryPrizePool.address, ethers.utils.parseEther("10000000000").div(100).mul(5));

        console.log(await token.balanceOf(admin.address))
        console.log(await token.balanceOf(firstBuyLotteryPrizePool.address))
        console.log(await token.balanceOf(await pancakeFactory.getPair(token.address, WBNB_ADDRESS)))
    })

    it ("First Buy Lottery", async () => {
        await pancakeRouter.connect(rion).swapExactETHForTokensSupportingFeeOnTransferTokens(
            ethers.utils.parseEther("1"),
            [
                WBNB_ADDRESS,
                token.address
            ],
            rion.address,
            ethers.constants.MaxUint256,
            {value: ethers.utils.parseEther("1")}
        )
        console.log(await token.rounds("0xb7b10297a278d5822fd6fec5277df16de3178518dbdc9e995c1504b42ebef9d5"))
        // await token.connect(firstBuyLotteryPrizePool).transfer(admin.address, BigNumber.from("375049233832347910968733749"))
        const tx =await token.rawFulfillRandomWords(
            BigNumber.from("0xb7b10297a278d5822fd6fec5277df16de3178518dbdc9e995c1504b42ebef9d5"),
            [0, 0],
        )
        console.log((await tx.wait()).gasUsed)
        console.log(await token.rounds("0xb7b10297a278d5822fd6fec5277df16de3178518dbdc9e995c1504b42ebef9d5"))
    })
    it ("Holders Lottery", async () => {
        await token.transfer(mephala.address, ethers.utils.parseEther("1000000"))
        await token.transfer(orrin.address, ethers.utils.parseEther("1000000"))
        console.log(await token.rounds("0x51f3dfe36b59e070617d445b9a6dcd11ecdd4fbf7be441290be0e2854b08171e"))
        const tx =await token.rawFulfillRandomWords(
            BigNumber.from("0x51f3dfe36b59e070617d445b9a6dcd11ecdd4fbf7be441290be0e2854b08171e"),
            [2],
        )
        console.log((await tx.wait()).gasUsed)
        console.log(rion.address, orrin.address, mephala.address)
        console.log(await token.rounds("0x51f3dfe36b59e070617d445b9a6dcd11ecdd4fbf7be441290be0e2854b08171e"))
     })
    it ("Donation Lottery", async () => {
        await token.connect(mephala).transfer(donationRecipient.address, ethers.utils.parseEther("1000"))
        await token.connect(orrin).transfer(donationRecipient.address, ethers.utils.parseEther("1000"))
        console.log(await token.rounds("0x5f37632b8819ea804e42c59eca4233994614f37c759602d6274b4415f2ba6182"))
        const tx =await token.rawFulfillRandomWords(
            BigNumber.from("0x5f37632b8819ea804e42c59eca4233994614f37c759602d6274b4415f2ba6182"),
            [2],
        )
        console.log((await tx.wait()).gasUsed)
        console.log(rion.address, orrin.address, mephala.address)
        console.log(await token.rounds("0x5f37632b8819ea804e42c59eca4233994614f37c759602d6274b4415f2ba6182"))
    })
    
})
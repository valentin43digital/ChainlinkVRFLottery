// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
    ConsumerConfig
} from "../lib/configs/VRFConsumerConfig.sol";


interface IConfiguration {

    function setConsumerConfig (ConsumerConfig calldata _newConfig) external;

	function setSubscriptionId (uint64 _subscriptionId) external;

	function setCallbackGasLimit (uint32 _callbackGasLimit) external;

	function setRequestConfirmations (uint16 _requestConfirmations) external;

	function setGasPriceKey (bytes32 _gasPriceKey) external;

	function setHolderLotteryPrizePoolAddress (address _newAddress) external;

	function setFirstBuyLotteryPrizePoolAddress (address _newAddress) external;

	function setDonationLotteryPrizePoolAddress (address _newAddress) external;

	function setTeamAddress (address _newAddress) external;

	function setTeamAccumulationAddress (address _newAddress) external;

	function setTreasuryAddress (address _newAddress) external;

	function setTreasuryAccumulationAddress (address _newAddress) external;

	function setFeeConfig (uint256 _feeConfigRaw) external;

	function switchFirstBuyLotteryFlag (bool flag) external;

    function switchHoldersLotteryFlag (bool flag) external;

    function switchDonationsLotteryFlag (bool flag) external;

	function excludeFromFee (address account) external;

	function includeInFee (address account) external;

	function setHoldersLotteryTxTrigger (uint64 _txAmount) external;

    function setDonationLotteryTxTrigger (uint64 _txAmount) external;

    function setHoldersLotteryMinPercent (uint256 _minPercent) external;

    function setDonationAddress (address _donationAddress) external;

    function setMinimanDonation (uint256 _minimalDonation) external;

    function setMinimumDonationEntries (uint64 _minimumEntries) external;

	function burnFeePercent () external view returns (uint256);

	function liquidityFeePercent () external view returns (uint256);

	function distributionFeePercent () external view returns (uint256);

	function treasuryFeePercent () external view returns (uint256);

	function devFeePercent () external view returns (uint256);

	function firstBuyLotteryPrizeFeePercent () external view returns (uint256);

	function holdersLotteryPrizeFeePercent () external view returns (uint256);

	function donationLotteryPrizeFeePercent () external view returns (uint256);

	function isExcludedFromFee (address account) external view returns (bool);

	function isExcludedFromReward (address account) external view returns (bool);

	function firstBuyLotteryEnabled () external view returns (bool);

    function holdersLotteryEnabled () external view returns (bool);

    function holdersLotteryTxTrigger () external view returns (uint64);

    function holdersLotteryMinPercent () external view returns (uint256);

    function donationAddress () external view returns (address);

    function donationsLotteryEnabled () external view returns (bool);

    function minimumDonationEntries () external view returns (uint64);

    function donationLotteryTxTrigger () external view returns (uint64);

    function minimalDonation () external view returns (uint256);

	function subscriptionId () external view returns (uint64);

	function callbackGasLimit () external view returns (uint32);

	function requestConfirmations () external view returns (uint16);

	function gasPriceKey () external view returns (bytes32);
}
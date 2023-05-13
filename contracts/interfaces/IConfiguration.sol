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

	function setDevFundWalletAddress (address _newAddress) external;

	function setTreasuryAddress (address _newAddress) external;

	function setFeeConfig (uint256 _feeConfigRaw) external;

	function switchFirstBuyLotteryFlag (bool flag) external;

    function switchHoldersLotteryFlag (bool flag) external;

    function switchDonationsLotteryFlag (bool flag) external;

	function excludeFromFee (address account) external;

	function includeInFee (address account) external;
}
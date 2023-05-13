// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
	Ownable
} from "@openzeppelin/contracts/access/Ownable.sol";

import {
	IConfiguration
} from "../../interfaces/IConfiguration.sol";

import {
	ConsumerConfig,
	VRFConsumerConfig
} from "./VRFConsumerConfig.sol";

import {
	DistributionConfig,
	ProtocolConfig
} from "./ProtocolConfig.sol";

import {
	LotteryConfig,
	LotteryEngineConfig
} from "./LotteryEngineConfig.sol";

abstract contract Configuration is IConfiguration, VRFConsumerConfig,
	ProtocolConfig, LotteryEngineConfig, Ownable {

	uint256 internal _creationTime;

	constructor (
		ConsumerConfig memory _consumerConfig,
		DistributionConfig memory _distributionConfig,
		LotteryConfig memory _lotteryConfig
	) VRFConsumerConfig (
		_consumerConfig
	) ProtocolConfig(
		_distributionConfig
	) LotteryEngineConfig(
		_lotteryConfig
	){
		_creationTime = block.timestamp;
	}

	function setConsumerConfig (
		ConsumerConfig calldata _newConfig
	) external onlyOwner {
		_setConfig(_newConfig);
	}

	function setSubscriptionId (
		uint64 _subscriptionId
	) external onlyOwner {
		_setSubscriptionId(_subscriptionId);
	}

	function setCallbackGasLimit (
		uint32 _callbackGasLimit
	) external onlyOwner {
		_setCallbackGasLimit(_callbackGasLimit);
	}

	function setRequestConfirmations (
		uint16 _requestConfirmations
	) external onlyOwner {
		_setRequestConfirmations(_requestConfirmations);
	}

	function setGasPriceKey (
		bytes32 _gasPriceKey
	) external onlyOwner {
		_setGasPriceKey(_gasPriceKey);
	}

	function setHolderLotteryPrizePoolAddress (
		address _newAddress
	) external onlyOwner {
		_setHolderLotteryPrizePoolAddress(_newAddress);
	}

	function setFirstBuyLotteryPrizePoolAddress (
		address _newAddress
	) external onlyOwner {
		_setFirstBuyLotteryPrizePoolAddress(_newAddress);
	}

	function setDonationLotteryPrizePoolAddress (
		address _newAddress
	) external onlyOwner {
		_setDonationLotteryPrizePoolAddress(_newAddress);
	}

	function setDevFundWalletAddress (
		address _newAddress
	) external onlyOwner {
		_setDevFundWalletAddress(_newAddress);
	}

	function setTreasuryAddress (
		address _newAddress
	) external onlyOwner {
		_setTreasuryAddress(_newAddress);
	}

	function setFeeConfig (
		uint256 _feeConfigRaw
	) external onlyOwner {
		_setFeeConfig(_feeConfigRaw);
	}

	function switchFirstBuyLotteryFlag (bool flag) external onlyOwner {
        _switchFirstBuyLotteryFlag(flag);
    }

    function switchHoldersLotteryFlag (bool flag) external onlyOwner {
        _switchHoldersLotteryFlag(flag);
    }

    function switchDonationsLotteryFlag (bool flag) external onlyOwner {
        _switchDonationsLotteryFlag(flag);
    }

	function excludeFromFee (address account) external onlyOwner {
		_isExcludedFromFee[account] = true;
	}

	function includeInFee (address account) external onlyOwner {
		_isExcludedFromFee[account] = false;
	}
}
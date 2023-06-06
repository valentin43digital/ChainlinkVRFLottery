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

	uint256 internal immutable _creationTime;

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

	function setTeamAddress (
		address _newAddress
	) external onlyOwner {
		_setTeamAddress(_newAddress);
	}

	function setTeamAccumulationAddress (
		address _newAddress
	) external onlyOwner {
		_setTeamAccumulationAddress(_newAddress);
	}

	function setTreasuryAddress (
		address _newAddress
	) external onlyOwner {
		_setTreasuryAddress(_newAddress);
	}

	function setTreasuryAccumulationAddress (
		address _newAddress
	) external onlyOwner {
		_setTreasuryAccumulationAddress(_newAddress);
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

    function setHoldersLotteryTxTrigger (
		uint64 _txAmount
	) external onlyOwner {
        _setHoldersLotteryTxTrigger(_txAmount);
    }

    function setDonationLotteryTxTrigger (
		uint64 _txAmount
	) external onlyOwner {
        _setDonationLotteryTxTrigger(_txAmount);
    }

    function setHoldersLotteryMinBalance (
		uint256 _minBalance
	) external onlyOwner {
        _setHoldersLotteryMinBalance(_minBalance);
    }

    function setDonationAddress (
		address _donationAddress
	) external onlyOwner {
        _setDonationAddress(_donationAddress);
    }

    function setMinimanDonation (
		uint256 _minimalDonation
	) external onlyOwner {
        _setMinimanDonation(_minimalDonation);
    }

    function setMinimumDonationEntries (
		uint64 _minimumEntries
	) external onlyOwner {
       _setMinimumDonationEntries(_minimumEntries);
    }

	function burnFeePercent () external view returns (uint32) {
		return _fees.burnFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function liquidityFeePercent () external view returns (uint32) {
		return _fees.liquidityFeePercent (
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function distributionFeePercent () external view returns (uint32) {
		return _fees.distributionFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function treasuryFeePercent () external view returns (uint32) {
		return _fees.treasuryFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function devFeePercent () external view returns (uint32) {
		return _fees.devFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function firstBuyLotteryPrizeFeePercent () external view returns (uint32) {
		return _fees.firstBuyLotteryPrizeFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function holdersLotteryPrizeFeePercent () external view returns (uint32) {
		return _fees.holdersLotteryPrizeFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function donationLotteryPrizeFeePercent () external view returns (uint32) {
		return _fees.donationLotteryPrizeFeePercent(
			_lotteryConfig.firstBuyLotteryEnabled
		);
	}

	function isExcludedFromFee (address account) external view returns (bool) {
		return _isExcludedFromFee[account];
	}

	function isExcludedFromReward (address account) external view returns (bool) {
		return _isExcluded[account];
	}

	function firstBuyLotteryEnabled () external view returns (bool) {
        return _lotteryConfig.firstBuyLotteryEnabled;
    }

    function holdersLotteryEnabled () external view returns (bool) {
        return _lotteryConfig.firstBuyLotteryEnabled;
    }

    function holdersLotteryTxTrigger () external view returns (uint64) {
        return _lotteryConfig.holdersLotteryTxTrigger;
    }

    function holdersLotteryMinBalance () external view returns (uint256) {
        return _lotteryConfig.holdersLotteryMinBalance;
    }

    function donationAddress () external view returns (address) {
        return _lotteryConfig.donationAddress;
    }

    function donationsLotteryEnabled () external view returns (bool) {
        return _lotteryConfig.donationsLotteryEnabled;
    }

    function minimumDonationEntries () external view returns (uint64) {
        return _lotteryConfig.minimumDonationEntries;
    }

    function donationLotteryTxTrigger () external view returns (uint64) {
        return _lotteryConfig.donationLotteryTxTrigger;
    }

    function minimalDonation () external view returns (uint256) {
        return _lotteryConfig.minimalDonation;
    }

	function subscriptionId () external view returns (uint64) {
		return _consumerConfig.subscriptionId;
	}

	function callbackGasLimit () external view returns (uint32) {
		return _consumerConfig.callbackGasLimit;
	}

	function requestConfirmations () external view returns (uint16) {
		return _consumerConfig.requestConfirmations;
	}

	function gasPriceKey () external view returns (bytes32) {
		return _consumerConfig.gasPriceKey;
	}
}
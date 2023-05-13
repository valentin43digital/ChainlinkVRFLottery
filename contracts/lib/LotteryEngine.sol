// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
	VRFCoordinatorV2Interface
} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {
	ConsumerConfig,
	DistributionConfig,
	LotteryConfig,
	PancakeAdapter
} from "./PancakeAdapter.sol";

import {
	Counter,
	Holders,
	RuntimeCounter,
	HoldersLotteryConfig,
	FirstBuyLotteryConfig,
	DonationLotteryConfig,
	LotteryRound,
	LotteryType,
	JackpotEntry,
	DONATION_TICKET_TIMEOUT
} from "./ConstantsAndTypes.sol";

import {
	VRFConsumerBaseV2
} from "./chainlink/VRFConsumerBaseV2.sol";

/**

*/
abstract contract LotteryEngine is PancakeAdapter, VRFConsumerBaseV2 {

	mapping ( uint256 => LotteryRound) public rounds;

	mapping ( address => bool ) private _bought;
	mapping ( address => uint256 ) private _nextDonationTimstamp;
	address[] internal _donators;
	Holders internal _holders;

	Counter internal _counter;

	constructor (
		address _routerAddress,
		ConsumerConfig memory _consumerConfig,
		DistributionConfig memory _distributionConfig,
		LotteryConfig memory _lotteryConfig
	) PancakeAdapter(
		_routerAddress,
		_consumerConfig,
		_distributionConfig,
		_lotteryConfig
	) {}

	function _requestRandomWords(uint32 _wordsAmount) internal returns (uint256) {
		return	VRFCoordinatorV2Interface(VRF_COORDINATOR).requestRandomWords(
			_consumerConfig.gasPriceKey,
			_consumerConfig.subscriptionId,
			_consumerConfig.requestConfirmations,
			_consumerConfig.callbackGasLimit,
			_wordsAmount
		);
	}

	function _firstBuyLottery (
		address _transferrer,
		address _recipient,
		uint256 _amount,
		FirstBuyLotteryConfig memory _runtime
	) internal {
		if (_runtime.enabled) {
			if (_transferrer != PANCAKE_PAIR) {
				return;
			}

			if (_isExcluded[_recipient] || _isExcludedFromFee[_recipient]) {
				return;
			}

			if (!_bought[_recipient]) {
				return;
			}

			_bought[_recipient] = true;

			uint256 usdAmount = _TokenPriceInUSD(_amount) / _TUSD_DECIMALS;
			uint256 hundreds = usdAmount / 100;
			if (hundreds == 0) {
				return;
			}
			uint256 requestId = _requestRandomWords(2);
			rounds[requestId].lotteryType = LotteryType.JACKPOT;
			if (hundreds > 10) {
				rounds[requestId].jackpotEntry = JackpotEntry.USD_1000;
				return;
			}
			rounds[requestId].jackpotEntry = JackpotEntry(uint8(hundreds));
			rounds[requestId].jackpotPlayer = _recipient;
		}
	}

	function _triggerHoldersLottery (
		HoldersLotteryConfig memory _runtime,
		RuntimeCounter memory _runtimeCounter
	) internal {
		// increment tx counter.
		_runtimeCounter.increaseHoldersLotteryCounter();

		if (_runtimeCounter.holdersLotteryTxCounter() <  _runtime.lotteryTxTrigger) {
			return;
		}

		uint256 requestId = _requestRandomWords(1);
		rounds[requestId].lotteryType = LotteryType.HOLDERS;
	}

	function _donationsLottery (
		address _transferrer,
		address _recipient,
		uint256 _amount,
		DonationLotteryConfig memory _runtime,
		RuntimeCounter memory _runtimeCounter
	) internal {
		if (_runtime.enabled) {
			// if donation lottery is running, increment tx counter.
			_runtimeCounter.increaseDonationLotteryCounter();

			// if this transfer is a donation, add a ticket for transferrer.
			if (
				_recipient == _runtime.donationAddress && 
					_amount >= _runtime.minimalDonation
			) {
				if (block.timestamp > _nextDonationTimstamp[_transferrer]) {
					_donators.push(_transferrer);
					_nextDonationTimstamp[_transferrer] = 
						block.timestamp + DONATION_TICKET_TIMEOUT;
				}
			}

			// check if minimum donation entries requirement is met.
			if (_donators.length < _runtime.minimumEntries) {
				return;
			}

			// check if tx counter can trigger the lottery.
			if (
				_runtimeCounter.donationLotteryTxCounter() < 
					_runtime.lotteryTxTrigger
			) {
				return;
			}

			uint256 requestId = _requestRandomWords(1);
			rounds[requestId].lotteryType = LotteryType.DONATION;

			_runtimeCounter.resetDonationLotteryCounter();
			delete _donators;
		}
	}
}
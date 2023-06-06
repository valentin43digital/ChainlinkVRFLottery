// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

type Fee is uint256;
type Counter is uint256;
using {addition as +} for Counter global;

using TypesHelpers for Fee global;
using TypesHelpers for Counter global;
using TypesHelpers for Holders global;
using TypesHelpers for RuntimeCounter global;
using TypesHelpers for DistributionConfig global;
using TypesHelpers for LotteryConfig global;
using TypesHelpers for LotteryType global;

function addition(Counter a, Counter b) pure returns(Counter) {
	return Counter.wrap(Counter.unwrap(a) + Counter.unwrap(b));
}

function toRandomWords(
		uint256[] memory _array
	) pure returns (RandomWords memory _words) {
		assembly {
			_words := add(_array, ONE_WORD)
		}
	}

library TypesHelpers {

	function compact(
		DistributionConfig memory _config
	) internal pure returns (Fee) {
		uint256 raw = _config.burnFee;
		raw = (raw << 32) + _config.liquidityFee;
		raw = (raw << 32) + _config.distributionFee;
		raw = (raw << 32) + _config.treasuryFee;
		raw = (raw << 32) + _config.devFee;
		raw = (raw << 32) + _config.firstBuyLotteryPrizeFee;
		raw = (raw << 32) + _config.holdersLotteryPrizeFee;
		raw = (raw << 32) + _config.donationLotteryPrizeFee;
		return Fee.wrap(raw);
	}

    function burnFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 224);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function liquidityFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 192);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function distributionFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 160);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function treasuryFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 128);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function devFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 96);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function firstBuyLotteryPrizeFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 64);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function holdersLotteryPrizeFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig) >> 32);
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function donationLotteryPrizeFeePercent (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint32) {
		uint32 fee = uint32(Fee.unwrap(feeConfig));
		return _jackPotEnabled ? fee * 2 : fee;
	}

	function all (
		Fee feeConfig,
		bool _jackPotEnabled
	) internal pure returns (uint256) {
		return burnFeePercent(feeConfig, _jackPotEnabled) +
		liquidityFeePercent(feeConfig, _jackPotEnabled) +
		distributionFeePercent(feeConfig, _jackPotEnabled) +
		treasuryFeePercent(feeConfig, _jackPotEnabled) +
		devFeePercent(feeConfig, _jackPotEnabled) +
		firstBuyLotteryPrizeFeePercent(feeConfig, _jackPotEnabled) +
		holdersLotteryPrizeFeePercent(feeConfig, _jackPotEnabled) +
		donationLotteryPrizeFeePercent(feeConfig, _jackPotEnabled);
	}

	function toDonationLotteryRuntime (
		LotteryConfig memory _runtime
	) internal pure returns (DonationLotteryConfig memory donationRuntime) {
		assembly {
			donationRuntime := add(_runtime, FOUR_WORDS)
		}
	}

	function toFirstBuyLotteryRuntime (
		LotteryConfig memory _runtime
	) internal pure returns (FirstBuyLotteryConfig memory firstBuyRuntime) {
		assembly {
			firstBuyRuntime := _runtime
		}
	}

	function toHoldersLotteryRuntime (
		LotteryConfig memory _runtime
	) internal pure returns (HoldersLotteryConfig memory holdersRuntime) {
		assembly {
			holdersRuntime := add(_runtime, ONE_WORD)
		}
	}

	function store (RuntimeCounter memory _counter) internal pure returns (Counter counter) {
		return _counter.counter;
	}

	function increaseDonationLotteryCounter (
		RuntimeCounter memory _counter
	) internal pure {
		_counter.counter = _counter.counter + INCREMENT_DONATION_COUNTER;
	}

	function increaseHoldersLotteryCounter (
		RuntimeCounter memory _counter
	) internal pure {
		_counter.counter = _counter.counter + INCREMENT_HOLDER_COUNTER;
	}

	function donationLotteryTxCounter (
		RuntimeCounter memory _counter
	) internal pure returns (uint256) {
		return Counter.unwrap(_counter.counter) >> 128;
	}

	function holdersLotteryTxCounter (
		RuntimeCounter memory _counter
	) internal pure returns (uint256) {
		return uint256(uint128(Counter.unwrap(_counter.counter)));
	}

	function resetDonationLotteryCounter (
		RuntimeCounter memory _counter
	) internal pure {
		uint256 raw = Counter.unwrap(_counter.counter);
		_counter.counter = Counter.wrap(uint256(uint128(raw)));
	}

	function resetHoldersLotteryCounter (
		RuntimeCounter memory _counter
	) internal pure {
		uint256 raw = Counter.unwrap(_counter.counter) >> 128;
		raw <<= 128;
		_counter.counter = Counter.wrap(raw);
	}


	function counterMemPtr (
		Counter _counter
	) internal pure returns (RuntimeCounter memory runtimeCounter) {
		runtimeCounter.counter = _counter;
	}

	function add(Holders storage _holders, address _holder) internal {
		if (!exists(_holders, _holder)) {
			_holders.array.push(_holder);
			_holders.idx[_holder] = _holders.array.length;
		}
	}

	function remove(Holders storage _holders, address _holder) internal {

		uint256 holderIdx = _holders.idx[_holder];
		if (holderIdx == 0) {
			return;
		}

		uint256 arrayIdx = holderIdx - 1;
		uint256 lastIdx = _holders.array.length - 1;

		if (arrayIdx != lastIdx) {
			address lastElement = _holders.array[lastIdx];
			_holders.array[arrayIdx] = lastElement;
			_holders.idx[lastElement] = holderIdx;
		}

		_holders.array.pop();

		delete _holders.idx[_holder];
	}

	function exists(Holders storage _holders, address _holder) internal view returns (bool) {
		return _holders.idx[_holder] != 0;
	}

	function isActive(LotteryType _lotteryType) internal pure returns (bool res) {
		assembly {
			switch _lotteryType
				case 1 {
					res := true
				}
				case 2 {
					res := true
				}
				case 3 {
					res := true
				}
				default {}
		}
	}
}

struct RuntimeCounter {
	Counter counter;
}

/**
	Packed configuration variables of the VRF consumer contract.

	subscriptionId - subscription id.
	callbackGasLimit - the maximum gas limit supported for a
		fulfillRandomWords callback.
	requestConfirmations - the minimum number of confirmation blocks on 
		VRF requests before oracles respond.
	gasPriceKey - Coordinator contract selects callback gas price limit by
		this key.
*/
struct ConsumerConfig {
	uint64 subscriptionId;
	uint32 callbackGasLimit;
	uint16 requestConfirmations;
	bytes32 gasPriceKey;
}

struct DistributionConfig {
	address holderLotteryPrizePoolAddress;
	address firstBuyLotteryPrizePoolAddress;
	address donationLotteryPrizePoolAddress;
	address teamAddress;
	address treasuryAddress;
	address teamFeesAccumulationAddress;
	address treasuryFeesAccumulationAddress;
	uint32 burnFee;
	uint32 liquidityFee;
	uint32 distributionFee;
	uint32 treasuryFee;
	uint32 devFee;
	uint32 firstBuyLotteryPrizeFee;
	uint32 holdersLotteryPrizeFee;
	uint32 donationLotteryPrizeFee;
}

struct LotteryConfig {
	bool firstBuyLotteryEnabled;
	bool holdersLotteryEnabled;
    uint64 holdersLotteryTxTrigger;
	uint256 holdersLotteryMinBalance;
	address donationAddress;
	bool donationsLotteryEnabled;
	uint64 minimumDonationEntries;
    uint64 donationLotteryTxTrigger;
    uint256 minimalDonation;
}

struct DonationLotteryConfig {
	address donationAddress;
	bool enabled;
	uint64 minimumEntries;
    uint64 lotteryTxTrigger;
    uint256 minimalDonation;
}

struct FirstBuyLotteryConfig {
	bool enabled;
}

struct HoldersLotteryConfig {
	bool enabled;
    uint64 lotteryTxTrigger;
	uint256 holdersLotteryMinBalance;
}

struct Holders {
	address[] array;
	mapping (address => uint256) idx;
}

enum LotteryType {
	NONE,
	JACKPOT,
	HOLDERS,
	DONATION,
	FINISHED_JACKPOT,
	FINISHED_HOLDERS,
	FINISHED_DONATION
}

enum JackpotEntry {
	NONE,
	USD_100,
	USD_200,
	USD_300,
	USD_400,
	USD_500,
	USD_600,
	USD_700,
	USD_800,
	USD_900,
	USD_1000
}

struct LotteryRound {
	uint256 prize;
	LotteryType lotteryType;
	address winner;
	address jackpotPlayer;
	JackpotEntry jackpotEntry;
}

struct RandomWords {
	uint256 first;
	uint256 second;
}

address constant DEAD_ADDRESS = address(0);
uint256 constant MAX_UINT256 = type(uint256).max;
uint256 constant DAY_ONE_LIMIT = 50; 
uint256 constant DAY_TWO_LIMIT = 100;
uint256 constant DAY_THREE_LIMIT = 150;
uint256 constant SEVENTY_FIVE_PERCENTS = 7500;
uint256 constant TWENTY_FIVE_PERCENTS = 2500;
uint256 constant PRECISION = 10_000;
uint256 constant DONATION_TICKET_TIMEOUT = 3600;
uint256 constant ONE_WORD = 0x20;
uint256 constant FOUR_WORDS = 0x80;
uint256 constant TWENTY_FIVE_BITS = 25;
uint256 constant LOTTERY_CONFIG_SLOT = 10;
Counter constant INCREMENT_DONATION_COUNTER = Counter.wrap((uint256(1) << 128));
Counter constant INCREMENT_HOLDER_COUNTER = Counter.wrap(1);
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

type Fee is uint256;
type Counter is uint256;

struct RuntimeCounter {
    Counter counter;
}

/**
	Packed configuration variables of the VRF consumer contract.

	subscriptionId - subscription id.
	callbackGasLimit - the maximum gas limit supported for a fulfillRandomWords callback.
	requestConfirmations - the minimum number of confirmation blocks on VRF requests before oracles respond.
	gasPriceKey - Coordinator contract selects callback gas price limit by this key.
*/
struct ConsumerConfig {
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    bytes32 gasPriceKey;
}

struct DistributionConfig {
    address holderLotteryPrizePoolAddress;
    address smashTimeLotteryPrizePoolAddress;
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
    uint32 smashTimeLotteryPrizeFee;
    uint32 holdersLotteryPrizeFee;
    uint32 donationLotteryPrizeFee;
}

struct LotteryConfig {
    bool smashTimeLotteryEnabled;
    uint256 smashTimeLotteryConversionThreshold;
    bool holdersLotteryEnabled;
    uint64 holdersLotteryTxTrigger;
    uint256 holdersLotteryMinPercent;
    address donationAddress;
    bool donationsLotteryEnabled;
    uint64 minimumDonationEntries;
    uint256 minimalDonation;
    uint256 donationConversionThreshold;
}

struct DonationLotteryConfig {
    address donationAddress;
    bool enabled;
    uint64 minimumEntries;
    uint256 minimalDonation;
    uint256 donationConversionThreshold;
}

struct SmashTimeLotteryConfig {
    bool enabled;
    uint256 smashTimeLotteryConversionThreshold;
}

struct HoldersLotteryConfig {
    bool enabled;
    uint64 lotteryTxTrigger;
    uint256 holdersLotteryMinPercent;
}

struct Holders {
    address[] first;
    address[] second;
    mapping(address => uint256[2]) idx;
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
uint256 constant TWO_WORD = 0x40;
uint256 constant FIVE_WORDS = 0x100;
uint256 constant TWENTY_FIVE_BITS = 25;
uint256 constant LOTTERY_CONFIG_SLOT = 10;

Counter constant INCREMENT_HOLDER_COUNTER = Counter.wrap(1);

using {addition as +} for Counter global;

using TypesHelpers for Fee global;
using TypesHelpers for Counter global;
using TypesHelpers for Holders global;
using TypesHelpers for RuntimeCounter global;
using TypesHelpers for DistributionConfig global;
using TypesHelpers for LotteryConfig global;
using TypesHelpers for LotteryType global;

function addition(Counter a, Counter b) pure returns (Counter) {
    return Counter.wrap(Counter.unwrap(a) + Counter.unwrap(b));
}

function toRandomWords(uint256[] memory _array) pure returns (RandomWords memory _words) {
    assembly {
        _words := add(_array, ONE_WORD)
    }
}

library TypesHelpers {
    function compact(DistributionConfig memory _config) internal pure returns (Fee) {
        uint256 raw = _config.burnFee;
        raw = (raw << 32) + _config.liquidityFee;
        raw = (raw << 32) + _config.distributionFee;
        raw = (raw << 32) + _config.treasuryFee;
        raw = (raw << 32) + _config.devFee;
        raw = (raw << 32) + _config.smashTimeLotteryPrizeFee;
        raw = (raw << 32) + _config.holdersLotteryPrizeFee;
        raw = (raw << 32) + _config.donationLotteryPrizeFee;
        return Fee.wrap(raw);
    }

    function burnFeePercent(Fee feeConfig, uint256 fee) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 224)) / PRECISION;
    }

    function liquidityFeePercent(Fee feeConfig, uint256 fee) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 192)) / PRECISION;
    }

    function distributionFeePercent(Fee feeConfig, uint256 fee) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 160)) / PRECISION;
    }

    function treasuryFeePercent(Fee feeConfig, uint256 fee) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 128)) / PRECISION;
    }

    function devFeePercent(Fee feeConfig, uint256 fee) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 96)) / PRECISION;
    }

    function smashTimeLotteryPrizeFeePercent(
        Fee feeConfig,
        uint256 fee
    ) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 64)) / PRECISION;
    }

    function holdersLotteryPrizeFeePercent(
        Fee feeConfig,
        uint256 fee
    ) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig) >> 32)) / PRECISION;
    }

    function donationLotteryPrizeFeePercent(
        Fee feeConfig,
        uint256 fee
    ) internal pure returns (uint256) {
        return (fee * uint32(Fee.unwrap(feeConfig))) / PRECISION;
    }

    function toDonationLotteryRuntime(
        LotteryConfig memory _runtime
    ) internal pure returns (DonationLotteryConfig memory donationRuntime) {
        assembly {
            donationRuntime := add(_runtime, FIVE_WORDS)
        }
    }

    function toSmashTimeLotteryRuntime(
        LotteryConfig memory _runtime
    ) internal pure returns (SmashTimeLotteryConfig memory smashTimeRuntime) {
        assembly {
            smashTimeRuntime := _runtime
        }
    }

    function toHoldersLotteryRuntime(
        LotteryConfig memory _runtime
    ) internal pure returns (HoldersLotteryConfig memory holdersRuntime) {
        assembly {
            holdersRuntime := add(_runtime, TWO_WORD)
        }
    }

    function store(RuntimeCounter memory _counter) internal pure returns (Counter counter) {
        return _counter.counter;
    }

    function increaseHoldersLotteryCounter(RuntimeCounter memory _counter) internal pure {
        _counter.counter = _counter.counter + INCREMENT_HOLDER_COUNTER;
    }

    function holdersLotteryTxCounter(
        RuntimeCounter memory _counter
    ) internal pure returns (uint256) {
        return uint256(uint128(Counter.unwrap(_counter.counter)));
    }

    function resetHoldersLotteryCounter(RuntimeCounter memory _counter) internal pure {
        _counter.counter = Counter.wrap(Counter.unwrap(_counter.counter) & ~uint128(0));
    }

    function counterMemPtr(
        Counter _counter
    ) internal pure returns (RuntimeCounter memory runtimeCounter) {
        runtimeCounter.counter = _counter;
    }

    function allTickets(Holders storage _holders) internal view returns (address[] memory) {
        address[] memory merged = new address[](_holders.first.length + _holders.second.length);
        for (uint256 i = 0; i < merged.length; ++i) {
            merged[i] = i < _holders.first.length
                ? _holders.first[i]
                : _holders.second[i - _holders.first.length];
        }
        return merged;
    }

    function addFirst(Holders storage _holders, address _holder) internal {
        if (!existsFirst(_holders, _holder)) {
            _holders.first.push(_holder);
            _holders.idx[_holder][0] = _holders.first.length;
        }
    }

    function removeFirst(Holders storage _holders, address _holder) internal {
        // If the first index of _holder is 0 or the array is empty, no operation is needed
        if (_holders.idx[_holder].length == 0) {
            return;
        }
        if (_holders.first.length == 0) {
            return;
        }

        uint256 holderIdx = _holders.idx[_holder][0];
        uint256 arrayIdx = holderIdx - 1;
        address[] storage firstArray = _holders.first; // Local storage reference
        uint256 lastIdx = firstArray.length - 1;

        if (arrayIdx != lastIdx) {
            address lastElement = firstArray[lastIdx];
            firstArray[arrayIdx] = lastElement;
            _holders.idx[lastElement][0] = holderIdx;
        }

        firstArray.pop();
        delete _holders.idx[_holder];
    }

    function existsFirst(Holders storage _holders, address _holder) internal view returns (bool) {
        return _holders.idx[_holder][0] != 0;
    }

    function addSecond(Holders storage _holders, address _holder) internal {
        if (!existsSecond(_holders, _holder)) {
            _holders.second.push(_holder);
            _holders.idx[_holder][1] = _holders.second.length;
        }
    }

    function removeSecond(Holders storage _holders, address _holder) internal {
        // If the second index of _holder is 0 or the array is empty, no operation is needed
        if (_holders.idx[_holder].length < 2) {
            return;
        }
        if (_holders.second.length == 0) {
            return;
        }

        uint256 holderIdx = _holders.idx[_holder][1];
        uint256 arrayIdx = holderIdx - 1;
        address[] storage secondArray = _holders.second; // Local storage reference
        uint256 lastIdx = secondArray.length - 1;

        if (arrayIdx != lastIdx) {
            address lastElement = secondArray[lastIdx];
            secondArray[arrayIdx] = lastElement;
            _holders.idx[lastElement][1] = holderIdx;
        }

        secondArray.pop();
        _holders.idx[_holder][1] = 0; // Reset the index to indicate removal
    }

    function existsSecond(Holders storage _holders, address _holder) internal view returns (bool) {
        return _holders.idx[_holder][1] != 0;
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
            default {

            }
        }
    }

    // Function to get the number of tickets for a token holder
    function getNumberOfTickets(
        Holders storage _holders,
        address _holder
    ) internal view returns (uint256) {
        uint256 tickets = 0;

        // Check if the holder is in the first array
        if (_holders.idx[_holder][0] > 0) {
            // Subtract 1 because array indices start from 0, but we stored starting from 1
            uint256 indexInFirst = _holders.idx[_holder][0] - 1;
            if (indexInFirst < _holders.first.length && _holders.first[indexInFirst] == _holder) {
                tickets += 1;
            }
        }

        // Check if the holder is in the second array
        if (_holders.idx[_holder][1] > 0) {
            // Subtract 1 because array indices start from 0, but we stored starting from 1
            uint256 indexInSecond = _holders.idx[_holder][1] - 1;
            if (
                indexInSecond < _holders.second.length && _holders.second[indexInSecond] == _holder
            ) {
                tickets += 2;
            }
        }

        return tickets;
    }
}

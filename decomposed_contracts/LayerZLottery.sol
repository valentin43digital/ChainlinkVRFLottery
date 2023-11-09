// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2} from "./lib/chainlink/VRFConsumerBaseV2.sol";

import {HoldersLotteryConfig, RuntimeCounter, LotteryConfig, LotteryRound, ConsumerConfig, DistributionConfig, LotteryEngine} from "./lib/LotteryEngine.sol";
import "./SwapLockable.sol";

abstract contract LayerZLottery is
    VRFConsumerBaseV2,
    LotteryEngine,
    SwapLockable
{
    uint256 public smashTimeWins;
    uint256 public donationLotteryWinTimes;
    uint256 public holdersLotteryWinTimes;
    uint256 public totalAmountWonInSmashTimeLottery;
    uint256 public totalAmountWonInDonationLottery;
    uint256 public totalAmountWonInHoldersLottery;

    constructor(
        address _routerAddress,
        uint256 _fee,
        ConsumerConfig memory _cConfig,
        DistributionConfig memory _dConfig,
        LotteryConfig memory _lConfig
    ) LotteryEngine(_routerAddress, _fee, _cConfig, _dConfig, _lConfig) {}

    function _fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        _finishRound(_requestId, toRandomWords(_randomWords));
    }

    function _checkForHoldersLotteryEligibility(
        address _participant,
        uint256 _balanceThreshold
    ) internal {
        if (_participant == address(PANCAKE_ROUTER)) {
            return;
        }

        if (_participant == PANCAKE_PAIR) {
            return;
        }

        if (_isExcludedFromFee[_participant] || _isExcluded[_participant]) {
            return;
        }

        uint256 balance = balanceOf(_participant);

        if (balance < _balanceThreshold * 3) {
            _holders.removeSecond(_participant);
        } else {
            _holders.addSecond(_participant);
        }

        if (balance < _balanceThreshold) {
            _holders.removeFirst(_participant);
        } else {
            _holders.addFirst(_participant);
        }
    }

    function _holdersEligibilityThreshold(
        uint256 _minPercent
    ) internal view returns (uint256) {
        return ((_tTotal - balanceOf(DEAD_ADDRESS)) * _minPercent) / PRECISION;
    }

    function _holdersLottery(
        address _transferrer,
        address _recipient,
        HoldersLotteryConfig memory _runtime,
        RuntimeCounter memory _runtimeCounter
    ) internal {
        if (!_runtime.enabled) {
            return;
        }

        _checkForHoldersLotteryEligibility(
            _transferrer,
            _holdersEligibilityThreshold(_runtime.holdersLotteryMinPercent)
        );

        _checkForHoldersLotteryEligibility(
            _recipient,
            _holdersEligibilityThreshold(_runtime.holdersLotteryMinPercent)
        );

        _triggerHoldersLottery(_runtime, _runtimeCounter);
    }

    function _lotteryOnTransfer(
        address _transferrer,
        address _recipient,
        uint256 _amount,
        bool _takeFee
    ) internal {
        // Save configs and counter to memory to decrease amount of storage reads.
        LotteryConfig memory runtime = _lotteryConfig;
        RuntimeCounter memory runtimeCounter = _counter.counterMemPtr();

        _smashTimeLottery(
            _transferrer,
            _recipient,
            _amount,
            runtime.toSmashTimeLotteryRuntime()
        );

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(_transferrer, _recipient, _amount, _takeFee);

        _holdersLottery(
            _transferrer,
            _recipient,
            runtime.toHoldersLotteryRuntime(),
            runtimeCounter
        );

        _donationsLottery(
            _transferrer,
            _recipient,
            _amount,
            runtime.toDonationLotteryRuntime(),
            runtimeCounter
        );

        _counter = runtimeCounter.store();
    }

    function _swapAndLiquify(
        uint256 contractTokenBalance
    ) internal lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;
        uint256 nativeBalance = _swap(half);

        // add liquidity to pancake
        _liquify(otherHalf, nativeBalance);
    }

    function _swap(uint256 tokenAmount) internal returns (uint256) {
        return _swapTokensForBNB(tokenAmount);
    }

    function _liquify(uint256 tokenAmount, uint256 bnbAmount) private {
        _addLiquidity(tokenAmount, bnbAmount);
    }

    function _finishRound(
        uint256 _requestId,
        RandomWords memory _random
    ) private {
        LotteryRound storage round = rounds[_requestId];

        if (round.lotteryType == LotteryType.JACKPOT) {
            _finishSmashTimeLottery(round, _random);
        }

        if (round.lotteryType == LotteryType.HOLDERS) {
            _finishHoldersLottery(round, _random.first);
        }

        if (round.lotteryType == LotteryType.DONATION) {
            _finishDonationLottery(round, _random.first);
        }
    }

    function _calculateSmashTimeLotteryPrize() private view returns (uint256) {
        return
            (balanceOf(smashTimeLotteryPrizePoolAddress) *
                TWENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _calculateHoldersLotteryPrize() private view returns (uint256) {
        return
            (balanceOf(holderLotteryPrizePoolAddress) * SEVENTY_FIVE_PERCENTS) /
            PRECISION;
    }

    function _calculateDonationLotteryPrize() private view returns (uint256) {
        return
            (balanceOf(donationLotteryPrizePoolAddress) *
                SEVENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _seedTicketsArray(
        address[100] memory _tickets,
        uint256 _index,
        address _player
    ) internal pure {
        if (_tickets[_index] == _player) {
            _seedTicketsArray(_tickets, _index + 1, _player);
        } else {
            _tickets[_index] = _player;
        }
    }

    function _finishSmashTimeLottery(
        LotteryRound storage _round,
        RandomWords memory _random
    ) private {
        address player = _round.jackpotPlayer;
        address[100] memory tickets;
        for (uint256 i; i < uint8(_round.jackpotEntry); ) {
            uint256 shift = (i * TWENTY_FIVE_BITS);
            uint256 idx = _random.second >> shift;
            assembly {
                idx := mod(idx, 100)
            }
            _seedTicketsArray(tickets, idx, player);
            unchecked {
                ++i;
            }
        }

        uint256 winnerIdx;
        assembly {
            winnerIdx := mod(mload(_random), 100)
        }

        if (tickets[winnerIdx] == player) {
            uint256 prize = _calculateSmashTimeLotteryPrize();
            _tokenTransfer(
                smashTimeLotteryPrizePoolAddress,
                address(this),
                prize,
                false
            );

            _swapTokensForBNB(prize, player);
            totalAmountWonInSmashTimeLottery += prize;
            smashTimeWins += 1;
            _round.winner = player;
            _round.prize = prize;
        }

        _round.lotteryType = LotteryType.FINISHED_JACKPOT;
    }

    function _finishHoldersLottery(
        LotteryRound storage _round,
        uint256 _random
    ) private {
        uint256 winnerIdx;
        uint256 holdersLength = _holders.first.length + _holders.second.length;

        if (holdersLength == 0) {
            return;
        }

        assembly {
            winnerIdx := mod(_random, holdersLength)
        }
        address winner = _holders.allTickets()[winnerIdx];
        uint256 prize = _calculateHoldersLotteryPrize();

        _tokenTransfer(holderLotteryPrizePoolAddress, winner, prize, false);

        holdersLotteryWinTimes += 1;
        totalAmountWonInHoldersLottery += prize;
        _round.winner = winner;
        _round.prize = prize;
        _round.lotteryType = LotteryType.FINISHED_HOLDERS;
    }

    function _finishDonationLottery(
        LotteryRound storage _round,
        uint256 _random
    ) private {
        uint256 winnerIdx;
        uint256 donatorsLength = _donators.length;
        assembly {
            winnerIdx := mod(_random, donatorsLength)
        }
        address winner = _donators[winnerIdx];
        uint256 prize = _calculateDonationLotteryPrize();

        _tokenTransfer(
            donationLotteryPrizePoolAddress,
            address(this),
            prize,
            false
        );

        _swapTokensForBNB(prize, winner);

        donationLotteryWinTimes += 1;
        totalAmountWonInDonationLottery += prize;
        _round.winner = winner;
        _round.prize = prize;
        _round.lotteryType = LotteryType.FINISHED_DONATION;

        delete _donators;
        _donationRound += 1;
    }

    function updateHolderList(
        address[] calldata holdersToCheck
    ) external onlyOwner {
        for (uint i = 0; i < holdersToCheck.length; i++) {
            _checkForHoldersLotteryEligibility(
                holdersToCheck[i],
                ((_tTotal - balanceOf(DEAD_ADDRESS)) *
                    _lotteryConfig.holdersLotteryMinPercent) / PRECISION
            );
        }
    }
}

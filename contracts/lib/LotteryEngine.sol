// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {ConsumerConfig, DistributionConfig, LotteryConfig, PancakeAdapter} from "./PancakeAdapter.sol";
import {Counter, Holders, RuntimeCounter, HoldersLotteryConfig, SmashTimeLotteryConfig, DonationLotteryConfig, LotteryRound, LotteryType, JackpotEntry, DONATION_TICKET_TIMEOUT} from "./ConstantsAndTypes.sol";
import {VRFConsumerBaseV2} from "./chainlink/VRFConsumerBaseV2.sol";

abstract contract LotteryEngine is PancakeAdapter, VRFConsumerBaseV2 {
    error NoDonationTicketsToTransfer();
    error RecipientsLengthNotEqualToAmounts();

    mapping(uint256 => LotteryRound) public rounds;

    uint256 internal _donationRound;
    mapping(address => uint256) private _nextDonationTimestamp;
    mapping(uint256 => mapping(address => uint256[])) internal _donatorTicketIdxs;
    mapping(uint256 => mapping(address => bool)) private _hasDonated;
    address[] internal _donators;
    uint256 internal _uniqueDonatorsCounter;
    Holders internal _holders;

    Counter internal _counter;

    constructor(
        address _routerAddress,
        uint256 _fee,
        ConsumerConfig memory _consumerConfig,
        DistributionConfig memory _distributionConfig,
        LotteryConfig memory _lotteryConfig
    ) PancakeAdapter(_routerAddress, _fee, _consumerConfig, _distributionConfig, _lotteryConfig) {}

    function _requestRandomWords(uint32 _wordsAmount) internal returns (uint256) {
        return
            VRFCoordinatorV2Interface(VRF_COORDINATOR).requestRandomWords(
                _consumerConfig.gasPriceKey,
                _consumerConfig.subscriptionId,
                _consumerConfig.requestConfirmations,
                _consumerConfig.callbackGasLimit,
                _wordsAmount
            );
    }

    function _smashTimeLottery(
        address _transferrer,
        address _recipient,
        uint256 _amount,
        SmashTimeLotteryConfig memory _runtime
    ) internal {
        if (!_runtime.enabled) {
            return;
        }
        if (_transferrer != PANCAKE_PAIR) {
            return;
        }

        if (_isExcludedFromReward[_recipient]) {
            return;
        }

        if (_isExcludedFromFee[_recipient]) {
            return;
        }

        uint256 usdAmount = _TokenPriceInUSD(_amount) / _TUSD_DECIMALS;
        uint256 hundreds = usdAmount / 100;
        if (hundreds == 0) {
            return;
        }

        uint256 requestId = _requestRandomWords(2);
        rounds[requestId].lotteryType = LotteryType.JACKPOT;
        rounds[requestId].jackpotEntry = hundreds >= 10
            ? JackpotEntry.USD_1000
            : JackpotEntry(uint8(hundreds));
        rounds[requestId].jackpotPlayer = _recipient;
    }

    function _triggerHoldersLottery(
        HoldersLotteryConfig memory _runtime,
        RuntimeCounter memory _runtimeCounter
    ) internal {
        // increment tx counter.
        _runtimeCounter.increaseHoldersLotteryCounter();

        if (_runtimeCounter.holdersLotteryTxCounter() < _runtime.lotteryTxTrigger) {
            return;
        }

        if (_holders.first.length == 0 && _holders.second.length == 0) {
            return;
        }

        uint256 requestId = _requestRandomWords(1);
        rounds[requestId].lotteryType = LotteryType.HOLDERS;
        _runtimeCounter.resetHoldersLotteryCounter();
    }

    function _donationsLottery(
        address _transferrer,
        address _recipient,
        uint256 _amount,
        DonationLotteryConfig memory _runtime
    ) internal {
        if (!_runtime.enabled) {
            return;
        }
        // if this transfer is a donation, add a ticket for transferrer.
        if (_recipient == _runtime.donationAddress && _amount >= _runtime.minimalDonation) {
            if (block.timestamp > _nextDonationTimestamp[_transferrer]) {
                uint256 length = _donators.length;
                _donators.push(_transferrer);
                _donatorTicketIdxs[_donationRound][_transferrer].push(length);
                if (!_hasDonated[_donationRound][_transferrer]) {
                    _hasDonated[_donationRound][_transferrer] = true;
                    _uniqueDonatorsCounter++;
                }
                _nextDonationTimestamp[_transferrer] = block.timestamp + DONATION_TICKET_TIMEOUT;
            }
        }

        // check if minimum donation entries requirement is met.
        if (_uniqueDonatorsCounter < _runtime.minimumEntries) {
            return;
        }

        uint256 requestId = _requestRandomWords(1);
        rounds[requestId].lotteryType = LotteryType.DONATION;
    }

    function transferDonationTicket(address _to) external {
        uint256 round = _donationRound;
        uint256 length = _donatorTicketIdxs[round][msg.sender].length;
        if (length == 0) {
            revert NoDonationTicketsToTransfer();
        }

        uint256 idx = _donatorTicketIdxs[round][msg.sender][length - 1];
        _donatorTicketIdxs[round][msg.sender].pop();
        _donators[idx] = _to;
        _donatorTicketIdxs[round][_to].push(idx);
    }

    function mintDonationTickets(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    ) external onlyOwner {
        uint256 recipientsLength = _recipients.length;
        if (recipientsLength != _amounts.length) {
            revert RecipientsLengthNotEqualToAmounts();
        }

        uint256 round = _donationRound;
        for (uint256 i = 0; i < recipientsLength; ++i) {
            address recipient = _recipients[i];
            uint256 amount = _amounts[i];
            uint256 idx = _donatorTicketIdxs[round][recipient].length;
            uint256 newIdx = idx + amount;

            for (; idx < newIdx; ++idx) {
                _donators.push(recipient);
                _donatorTicketIdxs[round][recipient].push(idx);
                if (!_hasDonated[_donationRound][recipient]) {
                    _hasDonated[_donationRound][recipient] = true;
                    _uniqueDonatorsCounter++;
                }
            }
        }
    }

    function holdersLotteryHolders() external view returns (address[] memory) {
        return _holders.allHolders();
    }

    function holdersLotteryTicketsAmountPerHolder(address _holder) external view returns (uint256) {
        return _holders.getNumberOfTickets(_holder);
    }

    function donationLotteryTickets() external view returns (address[] memory) {
        return _donators;
    }

    // Function to get the number of tickets for a donator
    function donationLotteryTicketsAmountPerDonator(
        address donator
    ) external view returns (uint256) {
        return _donatorTicketIdxs[_donationRound][donator].length;
    }
}

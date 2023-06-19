// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
    LotteryConfig
} from "../ConstantsAndTypes.sol";

abstract contract LotteryEngineConfig {

    LotteryConfig internal _lotteryConfig;

    constructor(
        LotteryConfig memory _config
    ) {
        _lotteryConfig = _config;
    }

    function _switchFirstBuyLotteryFlag (bool _flag) internal {
        _lotteryConfig.firstBuyLotteryEnabled = _flag;
    }

    function _switchHoldersLotteryFlag (bool _flag) internal {
        _lotteryConfig.holdersLotteryEnabled = _flag;
    }

    function _switchDonationsLotteryFlag (bool _flag) internal {
        _lotteryConfig.donationsLotteryEnabled = _flag;
    }

    function _setHoldersLotteryTxTrigger (uint64 _txAmount) internal {
        _lotteryConfig.holdersLotteryTxTrigger = _txAmount;
    }

    function _setDonationLotteryTxTrigger (uint64 _txAmount) internal {
        _lotteryConfig.donationLotteryTxTrigger = _txAmount;
    }

    function _setHoldersLotteryMinPercent (uint256 _minPercent) internal {
        _lotteryConfig.holdersLotteryMinPercent = _minPercent;
    }

    function _setDonationAddress (address _donationAddress) internal {
        _lotteryConfig.donationAddress = _donationAddress;
    }

    function _setMinimanDonation (uint256 _minimalDonation) internal {
        _lotteryConfig.minimalDonation = _minimalDonation;
    }

    function _setMinimumDonationEntries (uint64 _minimumEntries) internal {
        _lotteryConfig.minimumDonationEntries = _minimumEntries;
    }
}
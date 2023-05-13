// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
    LotteryConfig
} from "../ConstantsAndTypes.sol";

abstract contract LotteryEngineConfig {

    LotteryConfig public lotteryConfig;

    constructor(
        LotteryConfig memory _lotteryConfig
    ) {
        lotteryConfig = _lotteryConfig;
    }

    function _switchFirstBuyLotteryFlag (bool flag) internal {
        lotteryConfig.firstBuyLotteryEnabled = flag;
    }

    function _switchHoldersLotteryFlag (bool flag) internal {
        lotteryConfig.holdersLotteryEnabled = flag;
    }

    function _switchDonationsLotteryFlag (bool flag) internal {
        lotteryConfig.donationsLotteryEnabled = flag;
    }
}
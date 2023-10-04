// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
    IERC20
} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILotteryToken is IERC20 {

    function excludeFromReward (address account) external;

	function includeInReward (address account) external;

	function setWhitelist (address account, bool _status) external;

	function setMaxTxPercent (uint256 maxTxPercent) external;

	function setSwapAndLiquifyEnabled(bool _enabled) external;
}
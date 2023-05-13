// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
    IERC20
} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {
    IConfiguration
} from "./IConfiguration.sol";

interface ILotteryToken is IConfiguration, IERC20 {
    
}
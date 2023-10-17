// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../diamondBase/facets/BaseFacet.sol";

contract LZManagementFacet is BaseFacet {
    function totalFeePercent() external view returns (uint256) {
        return _calcFeePercent();
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    // whitelist to add liquidity
    function setWhitelist(address account, bool _status) external ownerOnly {
        whitelist[account] = _status;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external ownerOnly {
        maxTxAmount = (_tTotal * maxTxPercent) / PRECISION;
    }

    function setMaxBuyPercent(uint256 _maxBuyPercent) external ownerOnly {
        maxBuyPercent = _maxBuyPercent;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external ownerOnly {
        swapAndLiquifyEnabled = _enabled;
    }

    function setLiquiditySupplyThreshold(uint256 _amount) external ownerOnly {
        liquiditySupplyThreshold = _amount;
    }

    function setFeeSupplyThreshold(uint256 _amount) external ownerOnly {
        feeSupplyThreshold = _amount;
    }

    function setThreeDaysProtection(bool _enabled) external ownerOnly {
        threeDaysProtectionEnabled = _enabled;
    }

    function withdraw(uint256 _amount) external ownerOnly {
        _transferStandard(address(this), msg.sender, _amount, false);
    }

    function withdrawBNB(uint256 _amount) external ownerOnly {
        (bool res, ) = msg.sender.call{value: _amount}("");
        if (!res) {
            revert BNBWithdrawalFailed();
        }
    }
}
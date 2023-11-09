// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

abstract contract Unabuseable {
    uint256 public maxBuyPercent = 10_000;
    bool public threeDaysProtectionEnabled = false;

    function setThreeDaysProtection(bool _enabled) external onlyOwner {
        threeDaysProtectionEnabled = _enabled;
    }

    function setMaxBuyPercent(uint256 _maxBuyPercent) external onlyOwner {
        maxBuyPercent = _maxBuyPercent;
    }

    function _antiAbuse(address from, address to, uint256 amount) private view {
        if (from == owner() || to == owner())
            //  if owner we just return or we can't add liquidity
            return;

        uint256 allowedAmount;

        (, uint256 tSupply) = _getCurrentSupply();
        uint256 lastUserBalance = balanceOf(to) +
            ((amount * (PRECISION - _calcFeePercent())) / PRECISION);

        // bot \ whales prevention
        if (threeDaysProtectionEnabled) {
            if (block.timestamp <= (_creationTime + 1 days)) {
                allowedAmount = (tSupply * DAY_ONE_LIMIT) / PRECISION;

                if (lastUserBalance >= allowedAmount) {
                    revert TransferAmountExceededForToday();
                }
            }

            if (block.timestamp <= (_creationTime + 2 days)) {
                allowedAmount = (tSupply * DAY_TWO_LIMIT) / PRECISION;

                if (lastUserBalance >= allowedAmount) {
                    revert TransferAmountExceededForToday();
                }
            }

            if (block.timestamp <= (_creationTime + 3 days)) {
                allowedAmount = (tSupply * DAY_THREE_LIMIT) / PRECISION;

                if (lastUserBalance >= allowedAmount) {
                    revert TransferAmountExceededForToday();
                }
            }
        }
        if (amount > (balanceOf(PANCAKE_PAIR) * maxBuyPercent) / PRECISION) {
            revert TransferAmountExceedsPurchaseAmount();
        }
    }
}

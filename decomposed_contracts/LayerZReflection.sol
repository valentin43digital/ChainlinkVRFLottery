// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

abstract contract LayerZReflection {
    error TransferAmountExceededForToday();
    error TransferToZeroAddress();
    error TransferFromZeroAddress();
    error TransferAmountIsZero();
    error ExcludedAccountCanNotCall();
    error TransferAmountExceedsAllowance();
    error CanNotDecreaseAllowance();
    error AccountAlreadyExcluded();
    error AccountAlreadyIncluded();
    error CannotApproveToZeroAddress();
    error ApproveAmountIsZero();
    error AmountIsGreaterThanTotalReflections();
    error TransferAmountExceedsPurchaseAmount();
    error BNBWithdrawalFailed();

    struct TInfo {
        uint256 tTransferAmount;
        uint256 tBurnFee;
        uint256 tLiquidityFee;
        uint256 tDistributionFee;
        uint256 tTreasuryFee;
        uint256 tDevFundFee;
        uint256 tSmashTimePrizeFee;
        uint256 tHolderPrizeFee;
        uint256 tDonationLotteryPrizeFee;
    }

    struct RInfo {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rBurnFee;
        uint256 rLiquidityFee;
        uint256 rDistributionFee;
        uint256 rTreasuryFee;
        uint256 rDevFundFee;
        uint256 rSmashTimePrizeFee;
        uint256 rHolderPrizeFee;
        uint256 rDonationLotteryPrizeFee;
    }

    mapping(address => uint256) internal _rOwned;
    mapping(address => uint256) internal _tOwned;

    address[] internal _excluded;
    uint256 internal _tTotal = 10_000_000_000 * 1e18;
    uint256 internal _rTotal = (MAX_UINT256 - (MAX_UINT256 % _tTotal));
    uint256 internal _tFeeTotal;

    uint256 public feeSupplyThreshold = 1000 * 1e18;

    function setFeeSupplyThreshold(uint256 _amount) external onlyOwner {
        feeSupplyThreshold = _amount;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        if (_isExcluded[msg.sender]) {
            revert ExcludedAccountCanNotCall();
        }
        (RInfo memory rr, ) = _getValues(tAmount, true);
        _rOwned[msg.sender] -= rr.rAmount;
        _rTotal -= rr.rAmount;
        _tFeeTotal = _tFeeTotal - tAmount;
    }

    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) public view returns (uint256) {
        if (tAmount > _tTotal) {
            return 0;
        }

        (RInfo memory rr, ) = _getValues(tAmount, deductTransferFee);
        return rr.rTransferAmount;
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        if (rAmount > _rTotal) {
            revert AmountIsGreaterThanTotalReflections();
        }
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function _reflectFee(RInfo memory rr, TInfo memory tt) private {
        _rTotal -= rr.rDistributionFee;
        _tFeeTotal +=
            tt.tBurnFee +
            tt.tLiquidityFee +
            tt.tDistributionFee +
            tt.tTreasuryFee +
            tt.tDevFundFee +
            tt.tSmashTimePrizeFee +
            tt.tHolderPrizeFee +
            tt.tDonationLotteryPrizeFee;

        _rOwned[smashTimeLotteryPrizePoolAddress] += rr.rSmashTimePrizeFee;
        _rOwned[holderLotteryPrizePoolAddress] += rr.rHolderPrizeFee;
        _rOwned[donationLotteryPrizePoolAddress] += rr.rDonationLotteryPrizeFee;
        _rOwned[teamFeesAccumulationAddress] += rr.rDevFundFee;
        _rOwned[treasuryFeesAccumulationAddress] += rr.rTreasuryFee;
        _rOwned[DEAD_ADDRESS] += rr.rBurnFee;

        if (tt.tHolderPrizeFee > 0)
            emit Transfer(
                msg.sender,
                holderLotteryPrizePoolAddress,
                tt.tHolderPrizeFee
            );

        if (tt.tSmashTimePrizeFee > 0)
            emit Transfer(
                msg.sender,
                smashTimeLotteryPrizePoolAddress,
                tt.tSmashTimePrizeFee
            );

        if (tt.tDevFundFee > 0)
            emit Transfer(
                msg.sender,
                teamFeesAccumulationAddress,
                tt.tDevFundFee
            );

        if (tt.tTreasuryFee > 0)
            emit Transfer(
                msg.sender,
                treasuryFeesAccumulationAddress,
                tt.tTreasuryFee
            );

        if (tt.tDonationLotteryPrizeFee > 0)
            emit Transfer(
                msg.sender,
                donationLotteryPrizePoolAddress,
                tt.tDonationLotteryPrizeFee
            );

        if (tt.tBurnFee > 0)
            emit Transfer(msg.sender, DEAD_ADDRESS, tt.tBurnFee);
    }

    function _getValues(
        uint256 tAmount,
        bool takeFee
    ) private view returns (RInfo memory rr, TInfo memory tt) {
        tt = _getTValues(tAmount, takeFee);
        rr = _getRValues(tAmount, tt, _getRate());
        return (rr, tt);
    }

    function _getTValues(
        uint256 tAmount,
        bool takeFee
    ) private view returns (TInfo memory tt) {
        uint256 fee = _calcFeePercent();
        Fee fees = _fees;
        tt.tBurnFee = takeFee
            ? (fees.burnFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tDistributionFee = takeFee
            ? (fees.distributionFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tTreasuryFee = takeFee
            ? (fees.treasuryFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tDevFundFee = takeFee
            ? (fees.devFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tSmashTimePrizeFee = takeFee
            ? (fees.smashTimeLotteryPrizeFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tHolderPrizeFee = takeFee
            ? (fees.holdersLotteryPrizeFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tDonationLotteryPrizeFee = takeFee
            ? (fees.donationLotteryPrizeFeePercent(fee) * tAmount) / PRECISION
            : 0;
        tt.tLiquidityFee = takeFee
            ? (fees.liquidityFeePercent(fee) * tAmount) / PRECISION
            : 0;

        uint totalFee = tt.tBurnFee +
            tt.tLiquidityFee +
            tt.tDistributionFee +
            tt.tTreasuryFee +
            tt.tDevFundFee +
            tt.tSmashTimePrizeFee +
            tt.tDonationLotteryPrizeFee +
            tt.tHolderPrizeFee;

        tt.tTransferAmount = tAmount - totalFee;
        return tt;
    }

    function _getRValues(
        uint256 tAmount,
        TInfo memory tt,
        uint256 currentRate
    ) private pure returns (RInfo memory rr) {
        rr.rAmount = tAmount * currentRate;
        rr.rBurnFee = tt.tBurnFee * currentRate;
        rr.rLiquidityFee = tt.tLiquidityFee * currentRate;
        rr.rDistributionFee = tt.tDistributionFee * currentRate;
        rr.rTreasuryFee = tt.tTreasuryFee * currentRate;
        rr.rDevFundFee = tt.tDevFundFee * currentRate;
        rr.rSmashTimePrizeFee = tt.tSmashTimePrizeFee * currentRate;
        rr.rHolderPrizeFee = tt.tHolderPrizeFee * currentRate;
        rr.rDonationLotteryPrizeFee = tt.tDonationLotteryPrizeFee * currentRate;

        uint totalFee = rr.rBurnFee +
            rr.rLiquidityFee +
            rr.rDistributionFee +
            rr.rTreasuryFee +
            rr.rDevFundFee +
            rr.rSmashTimePrizeFee +
            rr.rDonationLotteryPrizeFee +
            rr.rHolderPrizeFee;

        rr.rTransferAmount = rr.rAmount - totalFee;
        return rr;
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) {
                return (_rTotal, _tTotal);
            }
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) {
            return (_rTotal, _tTotal);
        }
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 rLiquidity, uint256 tLiquidity) private {
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
    }

    function _distributeFees() private lockTheSwap {
        uint256 teamBalance = balanceOf(teamFeesAccumulationAddress);
        if (teamBalance >= feeSupplyThreshold) {
            uint256 balanceBefore = balanceOf(address(this));
            uint256 half = teamBalance / 2;
            uint256 otherHalf = balanceBefore - half;
            _tokenTransfer(
                teamFeesAccumulationAddress,
                address(this),
                teamBalance,
                false
            );
            uint256 forth = half / 2;
            uint256 otherForth = half - forth;
            _swapTokensForTUSDT(forth, teamAddress);
            _swapTokensForBNB(otherForth, teamAddress);
            uint256 balanceAfter = balanceOf(address(this));
            if (balanceAfter > 0) {
                _tokenTransfer(
                    address(this),
                    teamAddress,
                    balanceAfter - balanceBefore + otherHalf,
                    false
                );
            }
        }

        uint256 treasuryBalance = balanceOf(treasuryFeesAccumulationAddress);
        if (treasuryBalance >= feeSupplyThreshold) {
            uint256 balanceBefore = balanceOf(address(this));
            uint256 half = teamBalance / 2;
            uint256 otherHalf = balanceBefore - half;
            _tokenTransfer(
                treasuryFeesAccumulationAddress,
                address(this),
                treasuryBalance,
                false
            );
            uint256 forth = half / 2;
            uint256 otherForth = half - forth;
            _swapTokensForTUSDT(forth, treasuryAddress);
            _swapTokensForBNB(otherForth, treasuryAddress);
            uint256 balanceAfter = balanceOf(address(this));
            if (balanceAfter > 0) {
                _tokenTransfer(
                    address(this),
                    treasuryAddress,
                    balanceAfter - balanceBefore + otherHalf,
                    false
                );
            }
        }
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        bool senderExcluded = _isExcluded[sender];
        bool recipientExcluded = _isExcluded[recipient];

        if (!senderExcluded) {
            if (!recipientExcluded) {
                _transferStandard(sender, recipient, amount, takeFee);
            } else {
                _transferToExcluded(sender, recipient, amount, takeFee);
            }
        } else {
            if (recipientExcluded) {
                _transferBothExcluded(sender, recipient, amount, takeFee);
            } else {
                _transferFromExcluded(sender, recipient, amount, takeFee);
            }
        }
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        (RInfo memory rr, TInfo memory tt) = _getValues(tAmount, takeFee);
        _rOwned[sender] -= rr.rAmount;
        _rOwned[recipient] += rr.rTransferAmount;
        if (takeFee) {
            _takeLiquidity(rr.rLiquidityFee, tt.tLiquidityFee);
            _reflectFee(rr, tt);
        }

        emit Transfer(sender, recipient, tt.tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        (RInfo memory rr, TInfo memory tt) = _getValues(tAmount, takeFee);
        _rOwned[sender] -= rr.rAmount;
        _tOwned[recipient] += tt.tTransferAmount;
        _rOwned[recipient] += rr.rTransferAmount;

        if (takeFee) {
            _takeLiquidity(rr.rLiquidityFee, tt.tLiquidityFee);
            _reflectFee(rr, tt);
        }

        emit Transfer(sender, recipient, tt.tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        (RInfo memory rr, TInfo memory tt) = _getValues(tAmount, takeFee);
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rr.rAmount;
        _rOwned[recipient] += rr.rTransferAmount;

        if (takeFee) {
            _takeLiquidity(rr.rLiquidityFee, tt.tLiquidityFee);
            _reflectFee(rr, tt);
        }

        emit Transfer(sender, recipient, tt.tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        (RInfo memory rr, TInfo memory tt) = _getValues(tAmount, takeFee);
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rr.rAmount;
        _tOwned[recipient] += tt.tTransferAmount;
        _rOwned[recipient] += rr.rTransferAmount;

        if (takeFee) {
            _takeLiquidity(rr.rLiquidityFee, tt.tLiquidityFee);
            _reflectFee(rr, tt);
        }

        emit Transfer(sender, recipient, tt.tTransferAmount);
    }

    function totalFeePercent() external view returns (uint256) {
        return _calcFeePercent();
    }

    function excludeFromReward(address account) public onlyOwner {
        if (_isExcluded[account]) {
            revert AccountAlreadyExcluded();
        }

        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        if (!_isExcluded[account]) {
            revert AccountAlreadyIncluded();
        }
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
}

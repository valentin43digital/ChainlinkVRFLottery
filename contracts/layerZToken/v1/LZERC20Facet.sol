// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../diamondBase/facets/BaseFacet.sol";

contract LZERC20Facet is BaseFacet {
    modifier lockTheSwap() {
        _lock = SwapStatus.Locked;
        _;
        _lock = SwapStatus.Open;
    }

    modifier swapLockOnPairCall() {
        if (msg.sender == PANCAKE_PAIR) {
            _lock = SwapStatus.Locked;
            _;
            _lock = SwapStatus.Open;
        } else {
            _;
        }
    }

    function name() public pure returns (string memory) {
        return "LayerZ Token";
    }

    function symbol() public pure returns (string memory) {
        return "LayerZ";
    }

    function totalSupply() public view returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (_isExcluded[account]) {
            return _tOwned[account];
        }
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) {
            revert CannotApproveToZeroAddress();
        }
        if (amount == 0) {
            revert ApproveAmountIsZero();
        }

        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        if (_allowances[sender][msg.sender] < amount) {
            revert TransferAmountExceedsAllowance();
        }

        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX_UINT256) {
            unchecked {
                _allowances[sender][msg.sender] -= amount;
            }
        }
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        _allowances[msg.sender][spender] += addedValue;
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        if (_allowances[msg.sender][spender] < subtractedValue) {
            revert CanNotDecreaseAllowance();
        }
        _allowances[msg.sender][spender] -= subtractedValue;
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private swapLockOnPairCall {
        if (from == address(0)) {
            revert TransferFromZeroAddress();
        }
        if (to == address(0)) {
            revert TransferToZeroAddress();
        }
        if (amount == 0) {
            revert TransferAmountIsZero();
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        // whitelist to allow treasure to add liquidity:
        if (!whitelist[from] && !whitelist[to]) {
            if (from == PANCAKE_PAIR) {
                _antiAbuse(from, to, amount);
            }

            // is the token balance of this contract address over the min number of
            // tokens that we need to initiate a swap + liquidity lock?
            // also, don't get caught in a circular liquidity event.
            // also, don't swap & liquify if sender is uniswap pair.

            if (contractTokenBalance >= maxTxAmount) {
                contractTokenBalance = maxTxAmount;
            }
        }

        bool overMinTokenBalance = contractTokenBalance >=
            liquiditySupplyThreshold;
        if (
            overMinTokenBalance &&
            _lock == SwapStatus.Open &&
            from != PANCAKE_PAIR &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = liquiditySupplyThreshold;
            //add liquidity
            _swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = !_isExcludedFromFee[from] && !_isExcludedFromFee[to];

        _lotteryOnTransfer(from, to, amount, takeFee);

        // process transfer and lotteries
        if (_lock == SwapStatus.Open) {
            _distributeFees();
        }
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
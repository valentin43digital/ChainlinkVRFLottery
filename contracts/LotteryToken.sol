// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ILotteryToken} from "./interfaces/ILotteryToken.sol";
import {VRFConsumerBaseV2} from "./lib/chainlink/VRFConsumerBaseV2.sol";
import {HoldersLotteryConfig, RuntimeCounter, ConsumerConfig, DistributionConfig, LotteryConfig, LotteryEngine, LotteryRound} from "./lib/LotteryEngine.sol";
import {TWENTY_FIVE_BITS, DAY_ONE_LIMIT, DAY_TWO_LIMIT, DAY_THREE_LIMIT, MAX_UINT256, DEAD_ADDRESS, TWENTY_FIVE_PERCENTS, SEVENTY_FIVE_PERCENTS, PRECISION, LotteryType, RandomWords, toRandomWords, Fee} from "./lib/ConstantsAndTypes.sol";

contract LayerZ is LotteryEngine, ILotteryToken {
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

    enum SwapStatus {
        None,
        Open,
        Locked
    }

    uint256 public liquiditySupplyThreshold = 1000 * 1e18;
    uint256 public feeSupplyThreshold = 1000 * 1e18;

    uint256 public accruedLotteryTax;

    uint8 public constant decimals = 18;

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

    SwapStatus private _lock = SwapStatus.Open;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public whitelist;
    address[] private _excluded;

    uint256 private _tTotal = 10_000_000_000 * 1e18;

    uint256 public maxTxAmount = 10_000_000_000 * 1e18;

    uint256 public maxBuyPercent = 10_000;

    uint256 private _rTotal = (MAX_UINT256 - (MAX_UINT256 % _tTotal));
    uint256 private _tFeeTotal;

    bool public swapAndLiquifyEnabled = true;
    bool public threeDaysProtectionEnabled = false;

    uint256 public smashTimeWins;
    uint256 public donationLotteryWinTimes;
    uint256 public holdersLotteryWinTimes;
    uint256 public totalAmountWonInSmashTimeLottery;
    uint256 public totalAmountWonInDonationLottery;
    uint256 public totalAmountWonInHoldersLottery;

    constructor(
        address _mintSupplyTo,
        address _coordinatorAddress,
        address _routerAddress,
        uint256 _fee,
        ConsumerConfig memory _cConfig,
        DistributionConfig memory _dConfig,
        LotteryConfig memory _lConfig
    )
        VRFConsumerBaseV2(_coordinatorAddress)
        LotteryEngine(_routerAddress, _fee, _cConfig, _dConfig, _lConfig)
    {
        _rOwned[_mintSupplyTo] = _rTotal;
        emit Transfer(address(0), _mintSupplyTo, _tTotal);

        // we whitelist treasure and owner to allow pool management
        whitelist[_mintSupplyTo] = true;
        whitelist[owner()] = true;
        whitelist[address(this)] = true;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_lConfig.donationAddress] = true;
        _isExcludedFromFee[_mintSupplyTo] = true;
        _isExcludedFromFee[_dConfig.holderLotteryPrizePoolAddress] = true;
        _isExcludedFromFee[_dConfig.smashTimeLotteryPrizePoolAddress] = true;
        _isExcludedFromFee[_dConfig.donationLotteryPrizePoolAddress] = true;
        _isExcludedFromFee[_dConfig.teamAddress] = true;
        _isExcludedFromFee[_dConfig.teamFeesAccumulationAddress] = true;
        _isExcludedFromFee[_dConfig.treasuryAddress] = true;
        _isExcludedFromFee[_dConfig.treasuryFeesAccumulationAddress] = true;
        _isExcludedFromFee[_lotteryConfig.donationAddress] = true;
        _isExcludedFromFee[DEAD_ADDRESS] = true;
        _isExcludedFromFee[PANCAKE_PAIR] = true;
        _isExcludedFromFee[address(PANCAKE_ROUTER)] = true;

        _approve(address(this), address(PANCAKE_ROUTER), type(uint256).max);
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

    function acquireAccruedBNBLotteryTax() external onlyOwner {
        _swapTokensForBNB(accruedLotteryTax, owner());
        accruedLotteryTax = 0;
    }

    receive() external payable {}

    function _fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        _finishRound(_requestId, toRandomWords(_randomWords));
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

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
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

    function _checkForHoldersLotteryEligibility(
        address _participant,
        uint256 _balanceThreshold
    ) private {
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
    ) private view returns (uint256) {
        return ((_tTotal - balanceOf(DEAD_ADDRESS)) * _minPercent) / PRECISION;
    }

    function _holdersLottery(
        address _transferrer,
        address _recipient,
        HoldersLotteryConfig memory _runtime,
        RuntimeCounter memory _runtimeCounter
    ) private {
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
    ) private {
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

    function _swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;
        uint256 nativeBalance = _swap(half);

        // add liquidity to pancake
        _liquify(otherHalf, nativeBalance);
    }

    function _swap(uint256 tokenAmount) private returns (uint256) {
        return _swapTokensForBNB(tokenAmount);
    }

    function _liquify(uint256 tokenAmount, uint256 bnbAmount) private {
        _addLiquidity(tokenAmount, bnbAmount);
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
            uint256 untaxedPrize = _calculateSmashTimeLotteryPrize();
            uint256 tax = (untaxedPrize * smashTimeLotteryPrizeFeePercent()) /
                maxBuyPercent;
            accruedLotteryTax += tax;
            _tokenTransfer(
                smashTimeLotteryPrizePoolAddress,
                address(this),
                tax,
                false
            );

            uint256 prize = untaxedPrize - tax;
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

    function donate(uint256 _amount) external {
        _transfer(msg.sender, _lotteryConfig.donationAddress, _amount);
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

    // whitelist to add liquidity
    function setWhitelist(address account, bool _status) external onlyOwner {
        whitelist[account] = _status;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        maxTxAmount = (_tTotal * maxTxPercent) / PRECISION;
    }

    function setMaxBuyPercent(uint256 _maxBuyPercent) external onlyOwner {
        maxBuyPercent = _maxBuyPercent;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setLiquiditySupplyThreshold(uint256 _amount) external onlyOwner {
        liquiditySupplyThreshold = _amount;
    }

    function setFeeSupplyThreshold(uint256 _amount) external onlyOwner {
        feeSupplyThreshold = _amount;
    }

    function setThreeDaysProtection(bool _enabled) external onlyOwner {
        threeDaysProtectionEnabled = _enabled;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        _transferStandard(address(this), msg.sender, _amount, false);
    }

    function withdrawBNB(uint256 _amount) external onlyOwner {
        (bool res, ) = msg.sender.call{value: _amount}("");
        if (!res) {
            revert BNBWithdrawalFailed();
        }
    }
}

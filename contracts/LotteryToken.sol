// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PancakeAdapter} from "./lib/PancakeAdapter.sol";
import {Configuration, ConsumerConfig, DistributionConfig, LotteryConfig} from "./lib/configs/Configuration.sol";
import {TWENTY_FIVE_BITS, DAY_ONE_LIMIT, DAY_TWO_LIMIT, DAY_THREE_LIMIT, MAX_UINT256, DEAD_ADDRESS, TWENTY_FIVE_PERCENTS, SEVENTY_FIVE_PERCENTS, PRECISION, ONE_WORD, RandomWords, Fee, Holders, LotteryType, JackpotEntry} from "./lib/ConstantsAndTypes.sol";

contract TestZ is
    IERC20,
    AutomationCompatibleInterface,
    VRFConsumerBaseV2,
    PancakeAdapter,
    Configuration
{
    error TransferAmountExceededForToday();
    error TransferToZeroAddress();
    error TransferFromZeroAddress();
    error TransferAmountIsZero();
    error TransferAmountExceedsAllowance();
    error CanNotDecreaseAllowance();
    error AccountAlreadyExcluded();
    error AccountAlreadyIncluded();
    error CannotApproveToZeroAddress();
    error ApproveAmountIsZero();
    error AmountIsGreaterThanTotalReflections();
    error TransferAmountExceedsPurchaseAmount();
    error BNBWithdrawalFailed();
    error NoDonationTicketsToTransfer();
    error RecipientsLengthNotEqualToAmounts();

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

    uint8 public constant decimals = 18;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public whitelist;

    address[] private _excludedFromReward;

    uint256 public liquiditySupplyThreshold = 1000 * 1e18; // TODO:  use real value
    uint256 public feeSupplyThreshold = 1000 * 1e18; // TODO:  use real value
    uint256 private _tTotal = 10_000_000_000 * 1e18;
    uint256 private _rTotal = (MAX_UINT256 - (MAX_UINT256 % _tTotal));
    uint256 public maxTxAmount = 10_000_000_000 * 1e18;
    uint256 public maxBuyPercent = 10_000;
    uint256 private _tFeeTotal;

    bool public swapAndLiquifyEnabled = true;
    bool public threeDaysProtectionEnabled = false; // TODO:  use real value

    uint256 public smashTimeWins;
    uint256 public donationLotteryWinTimes;
    uint256 public holdersLotteryWinTimes;
    uint256 public totalAmountWonInSmashTimeLottery;
    uint256 public totalAmountWonInDonationLottery;
    uint256 public totalAmountWonInHoldersLottery;
    address public forwarderAddress;

    struct LotteryRound {
        uint256 prize;
        LotteryType lotteryType;
        address winner;
        address jackpotPlayer;
        JackpotEntry jackpotEntry;
    }

    mapping(uint256 => LotteryRound) public rounds;
    mapping(uint256 => mapping(address => uint256[])) private _donatorTicketIdxs;
    address[] private _donators;
    uint256 private _donationRound;
    uint256 private _uniqueDonatorsCounter;
    uint256 private _holdersLotteryTxCounter;

    Holders private _holders;

    IERC20 private _WBNB;
    VRFCoordinatorV2Interface private _COORDINATOR;

    mapping(uint256 => uint256) public donationRequestId;
    mapping(uint256 => uint256) public holderRequestId;
    mapping(uint256 => uint256) public smashtimeRequestId;

    uint256 public donationLotteryBNBPrize;
    uint256 public smashtimeLotteryBNBPrize;
    uint256 public donationLotteryPrizePoolAmount;
    uint256 public smashtimeLotteryPrizePoolAmount;

    constructor(
        address _mintSupplyTo,
        address _coordinatorAddress,
        address _routerAddress,
        address _wbnbAddress,
        address _tusdAddress,
        uint256 _fee,
        ConsumerConfig memory _consumerConfig,
        DistributionConfig memory _distributionConfig,
        LotteryConfig memory _lotteryConfig
    )
        VRFConsumerBaseV2(_coordinatorAddress)
        PancakeAdapter(_routerAddress, _wbnbAddress, _tusdAddress)
        Configuration(_fee, _consumerConfig, _distributionConfig, _lotteryConfig)
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
        _isExcludedFromFee[_lotteryConfig.donationAddress] = true;
        _isExcludedFromFee[_mintSupplyTo] = true;
        _isExcludedFromFee[_distributionConfig.holderLotteryPrizePoolAddress] = true;
        _isExcludedFromFee[_distributionConfig.smashTimeLotteryPrizePoolAddress] = true;
        _isExcludedFromFee[_distributionConfig.donationLotteryPrizePoolAddress] = true;
        _isExcludedFromFee[_distributionConfig.teamAddress] = true;
        _isExcludedFromFee[_distributionConfig.teamFeesAccumulationAddress] = true;
        _isExcludedFromFee[_distributionConfig.treasuryAddress] = true;
        _isExcludedFromFee[_distributionConfig.treasuryFeesAccumulationAddress] = true;
        _isExcludedFromFee[_lotteryConfig.donationAddress] = true;
        _isExcludedFromFee[DEAD_ADDRESS] = true;
        _isExcludedFromFee[address(PANCAKE_ROUTER)] = true;

        _approve(address(this), address(PANCAKE_ROUTER), MAX_UINT256);

        _WBNB = IERC20(_wbnbAddress);
        _COORDINATOR = VRFCoordinatorV2Interface(_coordinatorAddress);
    }

    function name() external pure returns (string memory) {
        return "TestZ Token"; // TODO: use real value
    }

    function symbol() external pure returns (string memory) {
        return "TestZ"; // TODO: use real value
    }

    function totalSupply() external view returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (_isExcludedFromReward[account]) {
            return _tOwned[account];
        }
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
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
    ) external returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        if (currentAllowance < amount) {
            revert TransferAmountExceedsAllowance();
        }

        _transfer(sender, recipient, amount);

        if (currentAllowance != MAX_UINT256) {
            unchecked {
                _allowances[sender][msg.sender] = currentAllowance - amount;
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
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert CanNotDecreaseAllowance();
        }
        _allowances[msg.sender][spender] = currentAllowance - subtractedValue;
        return true;
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) external view returns (uint256) {
        if (tAmount > _tTotal) {
            return 0;
        }

        (RInfo memory rr, ) = _getValues(tAmount, deductTransferFee);
        return rr.rTransferAmount;
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        if (rAmount > _rTotal) {
            revert AmountIsGreaterThanTotalReflections();
        }
        return rAmount / _getRate();
    }

    receive() external payable {}

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

        address[6] memory addresses = [
            holderLotteryPrizePoolAddress,
            smashTimeLotteryPrizePoolAddress,
            teamFeesAccumulationAddress,
            treasuryFeesAccumulationAddress,
            donationLotteryPrizePoolAddress,
            DEAD_ADDRESS
        ];

        uint256[6] memory fees = [
            tt.tHolderPrizeFee,
            tt.tSmashTimePrizeFee,
            tt.tDevFundFee,
            tt.tTreasuryFee,
            tt.tDonationLotteryPrizeFee,
            tt.tBurnFee
        ];

        for (uint i = 0; i < addresses.length; i++) {
            if (fees[i] > 0) {
                emit Transfer(msg.sender, addresses[i], fees[i]);
            }
        }
    }

    function _getValues(
        uint256 tAmount,
        bool takeFee
    ) private view returns (RInfo memory rr, TInfo memory tt) {
        tt = _getTValues(tAmount, takeFee);
        rr = _getRValues(tAmount, tt, _getRate());
        return (rr, tt);
    }

    function _getTValues(uint256 tAmount, bool takeFee) private view returns (TInfo memory tt) {
        if (!takeFee) {
            tt.tTransferAmount = tAmount;
            tt.tBurnFee = 0;
            tt.tDistributionFee = 0;
            tt.tTreasuryFee = 0;
            tt.tDevFundFee = 0;
            tt.tSmashTimePrizeFee = 0;
            tt.tHolderPrizeFee = 0;
            tt.tDonationLotteryPrizeFee = 0;
            tt.tLiquidityFee = 0;
            return tt;
        }

        uint256 _fee = _calcFeePercent();
        Fee fees = _fees;

        // Combined calculation for efficiency
        tt.tBurnFee = (fees.burnFeePercent(_fee) * tAmount) / PRECISION;
        tt.tDistributionFee = (fees.distributionFeePercent(_fee) * tAmount) / PRECISION;
        tt.tTreasuryFee = (fees.treasuryFeePercent(_fee) * tAmount) / PRECISION;
        tt.tDevFundFee = (fees.devFeePercent(_fee) * tAmount) / PRECISION;
        tt.tSmashTimePrizeFee = (fees.smashTimeLotteryPrizeFeePercent(_fee) * tAmount) / PRECISION;
        tt.tHolderPrizeFee = (fees.holdersLotteryPrizeFeePercent(_fee) * tAmount) / PRECISION;
        tt.tDonationLotteryPrizeFee =
            (fees.donationLotteryPrizeFeePercent(_fee) * tAmount) /
            PRECISION;
        tt.tLiquidityFee = (fees.liquidityFeePercent(_fee) * tAmount) / PRECISION;

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
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (
                _rOwned[_excludedFromReward[i]] > rSupply ||
                _tOwned[_excludedFromReward[i]] > tSupply
            ) {
                return (_rTotal, _tTotal);
            }
            rSupply = rSupply - _rOwned[_excludedFromReward[i]];
            tSupply = tSupply - _tOwned[_excludedFromReward[i]];
        }
        if (rSupply < _rTotal / _tTotal) {
            return (_rTotal, _tTotal);
        }
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 rLiquidity, uint256 tLiquidity) private {
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
        if (_isExcludedFromReward[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _antiAbuse(address from, address to, uint256 amount) private view {
        // If owner, skip checks
        if (from == owner() || to == owner()) return;

        (, uint256 tSupply) = _getCurrentSupply();
        uint256 lastUserBalance = balanceOf(to) +
            ((amount * (PRECISION - _calcFeePercent())) / PRECISION);

        // Bot / whales prevention
        if (threeDaysProtectionEnabled) {
            uint256 timeSinceCreation = block.timestamp - _creationTime;
            uint256 dayLimit = 0;

            if (timeSinceCreation <= 1 days) {
                dayLimit = DAY_ONE_LIMIT;
            } else if (timeSinceCreation <= 2 days) {
                dayLimit = DAY_TWO_LIMIT;
            } else if (timeSinceCreation <= 3 days) {
                dayLimit = DAY_THREE_LIMIT;
            }

            if (dayLimit > 0) {
                uint256 allowedAmount = (tSupply * dayLimit) / PRECISION;
                if (lastUserBalance >= allowedAmount) {
                    revert TransferAmountExceededForToday();
                }
            }
        }

        if (amount > (balanceOf(PANCAKE_PAIR) * maxBuyPercent) / PRECISION) {
            revert TransferAmountExceedsPurchaseAmount();
        }
    }

    function _transfer(address from, address to, uint256 amount) private swapLockOnPairCall {
        if (from == address(0)) revert TransferFromZeroAddress();
        if (to == address(0)) revert TransferToZeroAddress();
        if (amount == 0) revert TransferAmountIsZero();

        // whitelist to allow treasure to add liquidity:
        uint256 contractTokenBalance = balanceOf(address(this));
        if (!whitelist[from] && !whitelist[to]) {
            if (from == PANCAKE_PAIR) {
                _antiAbuse(from, to, amount);
            }
            // is the token balance of this contract address over the min number of
            // tokens that we need to initiate a swap + liquidity lock?
            // also, don't get caught in a circular liquidity event.
            // also, don't swap & liquify if sender is uniswap pair.
            if (contractTokenBalance >= maxTxAmount) contractTokenBalance = maxTxAmount;
        }
        if (
            contractTokenBalance >= liquiditySupplyThreshold &&
            _lock == SwapStatus.Open &&
            from != PANCAKE_PAIR &&
            to != PANCAKE_PAIR &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = liquiditySupplyThreshold;
            //add liquidity
            _swapAndLiquify(contractTokenBalance);
        }
        //indicates if fee should be deducted from transfer
        bool takeFee = !_isExcludedFromFee[from] && !_isExcludedFromFee[to];
        // process transfer and lotteries
        _lotteryOnTransfer(from, to, amount, takeFee);
        if (_lock == SwapStatus.Open) _distributeFees();
    }

    function _distributeFees() private lockTheSwap {
        _distributeFeeToAddress(teamFeesAccumulationAddress, teamAddress);
        _distributeFeeToAddress(treasuryFeesAccumulationAddress, treasuryAddress);
    }

    function _distributeFeeToAddress(
        address feeAccumulationAddress,
        address destinationAddress
    ) private {
        uint256 accumulatedBalance = balanceOf(feeAccumulationAddress);
        if (accumulatedBalance >= feeSupplyThreshold) {
            uint256 balanceBefore = balanceOf(address(this));

            _tokenTransfer(feeAccumulationAddress, address(this), accumulatedBalance, false);

            _swapTokensForTUSDT(accumulatedBalance / 4, destinationAddress);
            _swapTokensForBNB(accumulatedBalance / 4, destinationAddress);

            uint256 balanceAfter = balanceOf(address(this));

            if (balanceAfter > 0) {
                _tokenTransfer(
                    address(this),
                    destinationAddress,
                    balanceAfter - balanceBefore + accumulatedBalance / 2,
                    false
                );
            }
        }
    }

    function _checkForHoldersLotteryEligibility(
        address _participant,
        uint256 _balanceThreshold
    ) private {
        if (
            _participant == address(PANCAKE_ROUTER) ||
            _participant == PANCAKE_PAIR ||
            _isExcludedFromReward[_participant] ||
            _isExcludedFromFee[_participant]
        ) {
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

    function _holdersEligibilityThreshold(uint256 _minPercent) private view returns (uint256) {
        return ((_tTotal - balanceOf(DEAD_ADDRESS)) * _minPercent) / PRECISION;
    }

    function _checkForHoldersLotteryEligibilities(
        address _transferrer,
        address _recipient
    ) private {
        if (!_lotteryConfig.holdersLotteryEnabled) {
            return;
        }

        _holdersLotteryTxCounter++;

        _checkForHoldersLotteryEligibility(
            _transferrer,
            _holdersEligibilityThreshold(_lotteryConfig.holdersLotteryMinPercent)
        );

        _checkForHoldersLotteryEligibility(
            _recipient,
            _holdersEligibilityThreshold(_lotteryConfig.holdersLotteryMinPercent)
        );
    }

    function _convertSmashTimeLotteryPrize() private {
        uint256 conversionAmount = _calculateSmashTimeLotteryConversionAmount();
        _tokenTransfer(smashTimeLotteryPrizePoolAddress, address(this), conversionAmount, false);
        uint256 convertedBNB = _swapTokensForBNB(conversionAmount);
        smashtimeLotteryPrizePoolAmount -= conversionAmount;
        smashtimeLotteryBNBPrize += convertedBNB;
    }

    function _convertDonationLotteryPrize() private {
        uint256 conversionAmount = _calculateDonationLotteryConversionAmount();
        _tokenTransfer(donationLotteryPrizePoolAddress, address(this), conversionAmount, false);
        uint256 convertedBNB = _swapTokensForBNB(conversionAmount);
        donationLotteryPrizePoolAmount -= conversionAmount;
        donationLotteryBNBPrize += convertedBNB;
    }

    function _lotteryOnTransfer(
        address _transferrer,
        address _recipient,
        uint256 _amount,
        bool _takeFee
    ) private {
        _smashTimeLottery(_transferrer, _recipient, _amount);

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(_transferrer, _recipient, _amount, _takeFee);

        smashtimeLotteryPrizePoolAmount = balanceOf(smashTimeLotteryPrizePoolAddress);
        donationLotteryPrizePoolAmount = balanceOf(donationLotteryPrizePoolAddress);

        _checkForHoldersLotteryEligibilities(_transferrer, _recipient);

        _addDonationsLotteryTickets(_transferrer, _recipient, _amount);
    }

    function _requestRandomWords(uint32 _wordsAmount) private returns (uint256) {
        return
            _COORDINATOR.requestRandomWords(
                _consumerConfig.gasPriceKey,
                _consumerConfig.subscriptionId,
                _consumerConfig.requestConfirmations,
                _consumerConfig.callbackGasLimit,
                _wordsAmount
            );
    }

    function _toRandomWords(
        uint256[] memory _array
    ) private pure returns (RandomWords memory _words) {
        assembly {
            _words := add(_array, ONE_WORD)
        }
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        _finishRound(_requestId, _toRandomWords(_randomWords));
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        uint256 upkeepTasks = 0;
        if (smashtimeLotteryPrizePoolAmount >= _lotteryConfig.smashTimeLotteryConversionThreshold) {
            upkeepTasks |= 1;
        }

        if (donationLotteryPrizePoolAmount >= _lotteryConfig.donationConversionThreshold) {
            upkeepTasks |= 2;
        }
        if (
            _lotteryConfig.holdersLotteryEnabled &&
            _holdersLotteryTxCounter >= _lotteryConfig.holdersLotteryTxTrigger &&
            _holders.first.length != 0
        ) {
            upkeepTasks |= 4; // Set a bit for hodl lottery
        }
        if (
            _lotteryConfig.donationsLotteryEnabled &&
            _uniqueDonatorsCounter >= _lotteryConfig.minimumDonationEntries
        ) {
            upkeepTasks |= 8; // Set a bit for donation lottery
        }

        if (upkeepTasks != 0) {
            return (true, abi.encode(upkeepTasks));
        }

        return (false, bytes(""));
    }

    /// @notice Set the address that `performUpkeep` is called from
    /// @dev Only callable by the owner
    /// @param _forwarderAddress the address to set
    function setForwarderAddress(address _forwarderAddress) external onlyOwner {
        forwarderAddress = _forwarderAddress;
    }

    function performUpkeep(bytes calldata performData) external override {
        require(
            msg.sender == forwarderAddress,
            "This address does not have permission to call performUpkeep"
        );
        uint256 tasks = abi.decode(performData, (uint256));

        if (tasks & 1 != 0) {
            _convertSmashTimeLotteryPrize();
        }
        if (tasks & 2 != 0) {
            _convertDonationLotteryPrize();
        }
        if (tasks & 4 != 0) {
            _triggerHoldersLottery();
        }
        if (tasks & 8 != 0) {
            _donationsLottery();
        }
    }

    function _swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 nativeBalance = _swap(half);

        // add liquidity to pancake
        _liquify(half, nativeBalance);
    }

    function _swap(uint256 tokenAmount) private returns (uint256) {
        return _swapTokensForBNB(tokenAmount);
    }

    function _liquify(uint256 tokenAmount, uint256 bnbAmount) private {
        _addLiquidity(tokenAmount, bnbAmount, owner());
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        bool senderExcluded = _isExcludedFromReward[sender];
        bool recipientExcluded = _isExcludedFromReward[recipient];

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

    function _finishRound(uint256 _requestId, RandomWords memory _random) private {
        LotteryRound storage round = rounds[_requestId];

        if (round.lotteryType == LotteryType.JACKPOT) {
            _finishSmashTimeLottery(_requestId, round, _random);
        }

        if (round.lotteryType == LotteryType.HOLDERS) {
            _finishHoldersLottery(_requestId, round, _random.first);
        }

        if (round.lotteryType == LotteryType.DONATION) {
            _finishDonationLottery(_requestId, round, _random.first);
        }
    }

    function _calculateSmashTimeLotteryPrize() private view returns (uint256) {
        return (smashtimeLotteryBNBPrize * TWENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _calculateHoldersLotteryPrize() private view returns (uint256) {
        return (balanceOf(holderLotteryPrizePoolAddress) * SEVENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _calculateDonationLotteryPrize() private view returns (uint256) {
        return (donationLotteryBNBPrize * SEVENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _calculateDonationLotteryConversionAmount() private view returns (uint256) {
        return (balanceOf(donationLotteryPrizePoolAddress) * SEVENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _calculateSmashTimeLotteryConversionAmount() private view returns (uint256) {
        return (balanceOf(smashTimeLotteryPrizePoolAddress) * SEVENTY_FIVE_PERCENTS) / PRECISION;
    }

    function _seedTicketsArray(
        address[100] memory _tickets,
        uint256 _index,
        address _player
    ) private pure {
        while (_tickets[_index] == _player) {
            _index = (_index + 1) % 100;
        }
        _tickets[_index] = _player;
    }

    function _finishSmashTimeLottery(
        uint256 _requestId,
        LotteryRound storage _round,
        RandomWords memory _random
    ) private {
        address player = _round.jackpotPlayer;
        address[100] memory tickets;

        for (uint256 i = 0; i < uint8(_round.jackpotEntry); ) {
            uint256 shift = (i * TWENTY_FIVE_BITS);
            uint256 idx = (_random.second >> shift);
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
            uint256 tax = (untaxedPrize * smashTimeLotteryPrizeFeePercent()) / maxBuyPercent;

            require(address(this).balance >= untaxedPrize, "Insufficient balance");
            (bool taxSent, ) = owner().call{value: tax}("");
            require(taxSent, "Failed to send tax BNB in smashtime lottery");

            uint256 prize = untaxedPrize - tax;
            (bool prizeSent, ) = player.call{value: prize}("");
            require(prizeSent, "Failed to send prize BNB in smash lottery");

            smashtimeLotteryBNBPrize -= untaxedPrize;
            totalAmountWonInSmashTimeLottery += prize;
            smashtimeRequestId[smashTimeWins] = _requestId;
            smashTimeWins += 1;
            _round.winner = player;
            _round.prize = prize;
        }

        _round.lotteryType = LotteryType.FINISHED_JACKPOT;
    }

    function _finishHoldersLottery(
        uint256 _requestId,
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

        holderRequestId[holdersLotteryWinTimes] = _requestId;
        holdersLotteryWinTimes += 1;
        totalAmountWonInHoldersLottery += prize;
        _round.winner = winner;
        _round.prize = prize;
        _round.lotteryType = LotteryType.FINISHED_HOLDERS;
    }

    function _finishDonationLottery(
        uint256 _requestId,
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

        require(address(this).balance >= prize, "Insufficient balance");
        (bool sent, ) = winner.call{value: prize}("");
        require(sent, "Failed to send BNB");

        donationLotteryBNBPrize -= prize;
        donationRequestId[donationLotteryWinTimes] = _requestId;
        donationLotteryWinTimes += 1;
        totalAmountWonInDonationLottery += prize;
        _round.winner = winner;
        _round.prize = prize;
        _round.lotteryType = LotteryType.FINISHED_DONATION;

        delete _donators;
        _donationRound += 1;
    }

    function _smashTimeLottery(address _transferrer, address _recipient, uint256 _amount) private {
        if (
            !_lotteryConfig.smashTimeLotteryEnabled ||
            _transferrer != PANCAKE_PAIR ||
            _recipient == PANCAKE_PAIR ||
            _isExcludedFromReward[_recipient] ||
            _isExcludedFromFee[_recipient]
        ) {
            return;
        }

        uint256 usdAmount = _TokenPriceInUSD(_amount) / 1e18; // TODO: use correct decimal for stable coin
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

    function _triggerHoldersLottery() private {
        uint256 requestId = _requestRandomWords(1);
        rounds[requestId].lotteryType = LotteryType.HOLDERS;
        _holdersLotteryTxCounter = 0;
    }

    function _addDonationsLotteryTickets(
        address _transferrer,
        address _recipient,
        uint256 _amount
    ) private {
        if (!_lotteryConfig.donationsLotteryEnabled) {
            return;
        }
        // if this transfer is a donation, add a ticket for transferrer.
        if (
            _recipient == _lotteryConfig.donationAddress &&
            _amount >= _lotteryConfig.minimalDonation
        ) {
            if (_donatorTicketIdxs[_donationRound][_transferrer].length == 0) {
                _uniqueDonatorsCounter++;
            }
            uint256 length = _donators.length;
            _donators.push(_transferrer);
            _donatorTicketIdxs[_donationRound][_transferrer].push(length);
        }
    }

    function _donationsLottery() private {
        uint256 requestId = _requestRandomWords(1);
        rounds[requestId].lotteryType = LotteryType.DONATION;
        _uniqueDonatorsCounter = 0;
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
                if (_donatorTicketIdxs[_donationRound][recipient].length == 0) {
                    _uniqueDonatorsCounter++;
                }
                _donators.push(recipient);
                _donatorTicketIdxs[round][recipient].push(idx);
            }
        }
    }

    function holdersLotteryTickets() external view returns (address[] memory) {
        return _holders.allTickets();
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

    function donate(uint256 _amount) external {
        _transfer(msg.sender, _lotteryConfig.donationAddress, _amount);
    }

    function updateHolderList(address[] calldata holdersToCheck) external onlyOwner {
        for (uint i = 0; i < holdersToCheck.length; i++) {
            _checkForHoldersLotteryEligibility(
                holdersToCheck[i],
                ((_tTotal - balanceOf(DEAD_ADDRESS)) * _lotteryConfig.holdersLotteryMinPercent) /
                    PRECISION
            );
        }
    }

    function excludeFromReward(address account) external onlyOwner {
        if (_isExcludedFromReward[account]) {
            revert AccountAlreadyExcluded();
        }

        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = true;
        _excludedFromReward.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        if (!_isExcludedFromReward[account]) {
            revert AccountAlreadyIncluded();
        }
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (_excludedFromReward[i] == account) {
                _excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromReward[account] = false;
                _excludedFromReward.pop();
                break;
            }
        }
    }

    // Set functoins
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

    // Withdraw functions for this contract
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

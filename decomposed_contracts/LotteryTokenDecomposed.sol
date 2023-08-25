// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILotteryToken} from "./interfaces/ILotteryToken.sol";

import {
	TWENTY_FIVE_BITS, 
	DAY_ONE_LIMIT, 
	DAY_TWO_LIMIT, 
	DAY_THREE_LIMIT, 
	MAX_UINT256, 
	DEAD_ADDRESS, 
	TWENTY_FIVE_PERCENTS, 
	SEVENTY_FIVE_PERCENTS, 
	PRECISION, 
	LotteryType, 
	RandomWords, 
	toRandomWords, 
	Fee
} from "./lib/ConstantsAndTypes.sol";

import "./LayerZReflection.sol";
import "./LayerZLottery.sol";
import "./Unabuseable.sol";

contract LayerZ is 
    LayerZRelfection, 
    LayerZLottery, 
    Unabuseable
    ILotteryToken 
{
    bool public swapAndLiquifyEnabled = true;
    uint8 public constant decimals = 18;
    uint256 public maxTxAmount = 10_000_000_000 * 1e18;
    uint256 public liquiditySupplyThreshold = 1000 * 1e18;

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public whitelist;
    
    constructor(
        address _mintSupplyTo,
        address _coordinatorAddress,
        address _routerAddress,
        uint256 _fee,
        ConsumerConfig memory _cConfig,
        DistributionConfig memory _dConfig,
        LotteryConfig memory _lConfig
    )
        LayerZLottery(_routerAddress, _fee, _cConfig, _dConfig, _lConfig)
        VRFConsumerBaseV2(_coordinatorAddress)
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
        _isExcludedFromFee[_lConfig.donationAddress] = true;
        _isExcludedFromFee[DEAD_ADDRESS] = true;

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

    function donate(uint256 _amount) external {
        _transfer(msg.sender, _lotteryConfig.donationAddress, _amount);
    }

    receive() external payable {}

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

    // whitelist to add liquidity
    function setWhitelist(address account, bool _status) external onlyOwner {
        whitelist[account] = _status;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        maxTxAmount = (_tTotal * maxTxPercent) / PRECISION;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setLiquiditySupplyThreshold(uint256 _amount) external onlyOwner {
        liquiditySupplyThreshold = _amount;
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

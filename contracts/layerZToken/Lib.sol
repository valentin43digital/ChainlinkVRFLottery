// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library Lib {
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
        Open,
        None,
        Locked
    }

    bytes32 constant LOTTERY_TOKEN_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.lottery_token");

    uint8 public constant decimals = 18;

    struct ManagementReferenceTypes {
        mapping(address => bool) whitelist;
        bool swapAndLiquifyEnabled; // = true;
        bool threeDaysProtectionEnabled;
    }

    struct ERC20ReferenceTypes {
        mapping(address => mapping(address => uint256)) _allowances;
    }

    struct LotteryPrimitives {
        uint256 liquiditySupplyThreshold; // = 1000 * 1e18;
        uint256 feeSupplyThreshold; // = 1000 * 1e18;
        uint256 accruedLotteryTax;
        SwapStatus _lock;
        uint256 maxTxAmount; // = 10_000_000_000 * 1e18;
        uint256 maxBuyPercent; // = 10_000;
        uint256 smashTimeWins;
        uint256 donationLotteryWinTimes;
        uint256 holdersLotteryWinTimes;
        uint256 totalAmountWonInSmashTimeLottery;
        uint256 totalAmountWonInDonationLottery;
        uint256 totalAmountWonInHoldersLottery;
    }

    struct ReflectionReferenceTypes {
        mapping(address => uint256) _rOwned;
        mapping(address => uint256) _tOwned;
        address[] _excluded;
    }

    struct ReflectionPrimitives {
        uint256 _tTotal; // = 10_000_000_000 * 1e18;
        uint256 _rTotal; //= (MAX_UINT256 - (MAX_UINT256 % _tTotal));
        uint256 _tFeeTotal;
        uint256 feeSupplyThreshold; // = 1000 * 1e18;
    }

    struct Reflection {
        ReflectionPrimitives rp;
        ReflectionReferenceTypes rrt;
    }

    struct Storage {
        uint256 some;
    }

    function get() internal pure returns (Storage storage s) {
        bytes32 position = LOTTERY_TOKEN_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
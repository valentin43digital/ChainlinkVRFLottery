// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IPancakeRouter02} from "../interfaces/IPancakeRouter02.sol";
import {IPancakeFactory} from "../interfaces/IPancakeFactory.sol";
import {Configuration} from "./configs/Configuration.sol";
import {ConsumerConfig, DistributionConfig, LotteryConfig} from "./ConstantsAndTypes.sol";

abstract contract PancakeAdapter is Configuration {
    address internal constant _TUSD_ADDRESS =
        0x40af3827F39D0EAcBF4A168f8D4ee67c121D11c9; // TODO: use real value for mainnet
    address internal constant _WBNB_ADDRESS =
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // TODO: use real value for mainnet
    uint256 internal constant _TUSD_DECIMALS = 1e18;

    IPancakeRouter02 public immutable PANCAKE_ROUTER;

    address public immutable PANCAKE_PAIR;

    constructor(
        address _routerAddress,
        uint256 _fee,
        ConsumerConfig memory _consumerConfig,
        DistributionConfig memory _distributionConfig,
        LotteryConfig memory _lotteryConfig
    )
        Configuration(
            _fee,
            _consumerConfig,
            _distributionConfig,
            _lotteryConfig
        )
    {
        PANCAKE_ROUTER = IPancakeRouter02(_routerAddress);
        PANCAKE_PAIR = _createPancakeSwapPair();
    }

    function _createPancakeSwapPair() internal returns (address) {
        return
            IPancakeFactory(PANCAKE_ROUTER.factory()).createPair(
                address(this),
                _WBNB_ADDRESS
            );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount) internal {
        PANCAKE_ROUTER.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function _swapTokensForBNB(
        uint256 _tokensAmount
    ) internal returns (uint256 bnbAmount) {
        uint256 balanceBeforeSwap = address(this).balance;
        // generate the pancakeswap pair path of Token -> BNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _WBNB_ADDRESS;

        // make the swap
        PANCAKE_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokensAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        unchecked {
            bnbAmount = address(this).balance - balanceBeforeSwap;
        }
    }

    function _swapTokensForBNB(uint256 _tokensAmount, address _to) internal {
        // generate the pancakeswap pair path of Token -> BNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _WBNB_ADDRESS;

        // make the swap
        PANCAKE_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            // _tokensAmount, // TODO: use this value for mainnet
            _tokensAmount / 10, // Divied by 10 for testnet
            0, // accept any amount of ETH
            path,
            _to,
            block.timestamp
        );
    }

    function _swapTokensForTUSDT(uint256 _tokensAmount, address _to) internal {
        // generate the pancake pairs path of Token -> BNB -> USDT
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = _WBNB_ADDRESS;
        path[2] = _TUSD_ADDRESS;

        PANCAKE_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokensAmount,
            0, // accept any amount of USDT
            path,
            _to,
            block.timestamp
        );
    }

    function _TokenPriceInUSD(
        uint256 _amount
    ) internal view returns (uint256 usdAmount) {
        // generate the uniswap pair path of BNB -> USDT
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = _WBNB_ADDRESS;
        path[2] = _TUSD_ADDRESS;

        usdAmount = PANCAKE_ROUTER.getAmountsOut(_amount, path)[2];
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IPancakeRouter02} from "../interfaces/IPancakeRouter02.sol";
import {IPancakeFactory} from "../interfaces/IPancakeFactory.sol";

abstract contract PancakeAdapter {
    address internal _USDT_ADDRESS;
    address internal _WBNB_ADDRESS;

    IPancakeRouter02 public immutable PANCAKE_ROUTER;

    address public immutable PANCAKE_PAIR;

    constructor(address _routerAddress, address _wbnbAddress, address _usdtAddress) {
        _WBNB_ADDRESS = _wbnbAddress;
        _USDT_ADDRESS = _usdtAddress;
        PANCAKE_ROUTER = IPancakeRouter02(_routerAddress);
        PANCAKE_PAIR = _createPancakeSwapPair();
    }

    function _createPancakeSwapPair() internal returns (address) {
        return IPancakeFactory(PANCAKE_ROUTER.factory()).createPair(address(this), _WBNB_ADDRESS);
    }

    function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount, address _to) internal {
        PANCAKE_ROUTER.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _to,
            block.timestamp
        );
    }

    function _swapTokensForBNB(uint256 _tokensAmount) internal returns (uint256 bnbAmount) {
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
            _tokensAmount,
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
        path[2] = _USDT_ADDRESS;

        PANCAKE_ROUTER.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokensAmount,
            0, // accept any amount of USDT
            path,
            _to,
            block.timestamp
        );
    }

    function _TokenPriceInUSD(uint256 _amount) internal view returns (uint256 usdAmount) {
        // generate the uniswap pair path of BNB -> USDT
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = _WBNB_ADDRESS;
        path[2] = _USDT_ADDRESS;

        usdAmount = PANCAKE_ROUTER.getAmountsOut(_amount, path)[2];
    }
}

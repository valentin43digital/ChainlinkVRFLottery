// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "../../diamondBase/facets/BaseFacet.sol";

contract LZInitializerFacet is BaseFacet {
    function initialize(
        address _owner,
        address _mintSupplyTo,
        address _routerAddress
    ) external {
        InitializerLib.initialize();
        _rOwned[_mintSupplyTo] = _rTotal;
        emit Transfer(address(0), _mintSupplyTo, _tTotal);

        // we whitelist treasure and owner to allow pool management
        whitelist[_mintSupplyTo] = true;
        whitelist[_owner()] = true;
        whitelist[address(this)] = true;

        //exclude owner and this contract from fee
        _isExcludedFromFee[_owner] = true;
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
}
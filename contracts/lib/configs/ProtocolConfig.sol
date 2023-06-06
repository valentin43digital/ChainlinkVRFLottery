// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {
	Fee,
	DistributionConfig,
	PRECISION
} from "../ConstantsAndTypes.sol";

/**

*/
abstract contract ProtocolConfig {

	address public holderLotteryPrizePoolAddress;
	address public firstBuyLotteryPrizePoolAddress;
	address public donationLotteryPrizePoolAddress;
	address public teamFeesAccumulationAddress;
	address public treasuryFeesAccumulationAddress;
	address public teamAddress;
	address public treasuryAddress;

	mapping( address => bool ) internal _isExcludedFromFee;
	mapping( address => bool ) internal _isExcluded;

	Fee internal _fees;

	constructor (
		DistributionConfig memory _config
	) {
		holderLotteryPrizePoolAddress = _config.holderLotteryPrizePoolAddress;
		firstBuyLotteryPrizePoolAddress = _config.firstBuyLotteryPrizePoolAddress;
		donationLotteryPrizePoolAddress = _config.donationLotteryPrizePoolAddress;
		teamFeesAccumulationAddress = _config.teamFeesAccumulationAddress;
		treasuryFeesAccumulationAddress = _config.treasuryFeesAccumulationAddress;
		teamAddress = _config.teamAddress;
		treasuryAddress = _config.treasuryAddress;
		_fees = _config.compact();
	}

	function _setHolderLotteryPrizePoolAddress (address _newAddress) internal {
		holderLotteryPrizePoolAddress = _newAddress;
	}

	function _setFirstBuyLotteryPrizePoolAddress (address _newAddress) internal {
		firstBuyLotteryPrizePoolAddress = _newAddress;
	}

	function _setDonationLotteryPrizePoolAddress (address _newAddress) internal {
		donationLotteryPrizePoolAddress = _newAddress;
	}

	function _setTeamAddress (address _newAddress) internal {
		teamAddress = _newAddress;
	}

	function _setTeamAccumulationAddress (address _newAddress) internal {
		teamFeesAccumulationAddress = _newAddress;
	}

	function _setTreasuryAccumulationAddress (address _newAddress) internal {
		treasuryFeesAccumulationAddress = _newAddress;
	}

	function _setTreasuryAddress (address _newAddress) internal {
		treasuryAddress = _newAddress;
	}

	function _setFeeConfig (uint256 _feeConfigRaw) internal {
		_fees = Fee.wrap(_feeConfigRaw);
	}
}
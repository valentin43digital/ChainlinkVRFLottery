// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IConfiguration} from "../../interfaces/IConfiguration.sol";
import {ConsumerConfig, VRFConsumerConfig} from "./VRFConsumerConfig.sol";
import {DistributionConfig, ProtocolConfig} from "./ProtocolConfig.sol";
import {LotteryConfig, LotteryEngineConfig} from "./LotteryEngineConfig.sol";

abstract contract Configuration is
    IConfiguration,
    VRFConsumerConfig,
    ProtocolConfig,
    LotteryEngineConfig,
    Ownable
{
    uint256 public constant FEE_CAP = 500;

    uint256 internal immutable _creationTime;
    uint256 public fee;

    constructor(
        uint256 _fee,
        ConsumerConfig memory _consumerConfig,
        DistributionConfig memory _distributionConfig,
        LotteryConfig memory _lotteryConfig
    )
        VRFConsumerConfig(_consumerConfig)
        ProtocolConfig(_distributionConfig)
        LotteryEngineConfig(_lotteryConfig)
    {
        fee = _fee;
        _creationTime = block.timestamp;
    }

    function _calcFeePercent() internal view returns (uint256) {
        uint256 currentFees = fee;

        if (_lotteryConfig.smashTimeLotteryEnabled) {
            currentFees *= 2;
        }

        return currentFees >= FEE_CAP ? FEE_CAP : currentFees;
    }

    function setConsumerConfig(ConsumerConfig calldata _newConfig) external onlyOwner {
        _setConfig(_newConfig);
    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        _setSubscriptionId(_subscriptionId);
    }

    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        _setCallbackGasLimit(_callbackGasLimit);
    }

    function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        _setRequestConfirmations(_requestConfirmations);
    }

    function setGasPriceKey(bytes32 _gasPriceKey) external onlyOwner {
        _setGasPriceKey(_gasPriceKey);
    }

    function setHolderLotteryPrizePoolAddress(address _newAddress) external onlyOwner {
        _setHolderLotteryPrizePoolAddress(_newAddress);
    }

    function setSmashTimeLotteryPrizePoolAddress(address _newAddress) external onlyOwner {
        _setSmashTimeLotteryPrizePoolAddress(_newAddress);
    }

    function setDonationLotteryPrizePoolAddress(address _newAddress) external onlyOwner {
        _setDonationLotteryPrizePoolAddress(_newAddress);
    }

    function setTeamAddress(address _newAddress) external onlyOwner {
        _setTeamAddress(_newAddress);
    }

    function setTeamAccumulationAddress(address _newAddress) external onlyOwner {
        _setTeamAccumulationAddress(_newAddress);
    }

    function setTreasuryAddress(address _newAddress) external onlyOwner {
        _setTreasuryAddress(_newAddress);
    }

    function setTreasuryAccumulationAddress(address _newAddress) external onlyOwner {
        _setTreasuryAccumulationAddress(_newAddress);
    }

    function setFeeConfig(uint256 _feeConfigRaw) external onlyOwner {
        _setFeeConfig(_feeConfigRaw);
    }

    function switchSmashTimeLotteryFlag(bool flag) external onlyOwner {
        _switchSmashTimeLotteryFlag(flag);
    }

    function switchHoldersLotteryFlag(bool flag) external onlyOwner {
        _switchHoldersLotteryFlag(flag);
    }

    function switchDonationsLotteryFlag(bool flag) external onlyOwner {
        _switchDonationsLotteryFlag(flag);
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setHoldersLotteryTxTrigger(uint64 _txAmount) external onlyOwner {
        _setHoldersLotteryTxTrigger(_txAmount);
    }

    function setHoldersLotteryMinPercent(uint256 _minPercent) external onlyOwner {
        _setHoldersLotteryMinPercent(_minPercent);
    }

    function setDonationAddress(address _donationAddress) external onlyOwner {
        _setDonationAddress(_donationAddress);
    }

    function setMinimalDonation(uint256 _minimalDonation) external onlyOwner {
        _setMinimanDonation(_minimalDonation);
    }

    function setDonationConversionThreshold(
        uint256 _donationConversionThreshold
    ) external onlyOwner {
        _setDonationConversionThreshold(_donationConversionThreshold);
    }

    function setSmashTimeLotteryConversionThreshold(
        uint256 _smashTimeLotteryConversionThreshold
    ) external onlyOwner {
        _setSmashTimeLotteryConversionThreshold(_smashTimeLotteryConversionThreshold);
    }

    function setFees(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setMinimumDonationEntries(uint64 _minimumEntries) external onlyOwner {
        _setMinimumDonationEntries(_minimumEntries);
    }

    function burnFeePercent() external view returns (uint256) {
        return _fees.burnFeePercent(_calcFeePercent());
    }

    function liquidityFeePercent() external view returns (uint256) {
        return _fees.liquidityFeePercent(_calcFeePercent());
    }

    function distributionFeePercent() external view returns (uint256) {
        return _fees.distributionFeePercent(_calcFeePercent());
    }

    function treasuryFeePercent() external view returns (uint256) {
        return _fees.treasuryFeePercent(_calcFeePercent());
    }

    function devFeePercent() external view returns (uint256) {
        return _fees.devFeePercent(_calcFeePercent());
    }

    function smashTimeLotteryPrizeFeePercent() public view returns (uint256) {
        return _fees.smashTimeLotteryPrizeFeePercent(_calcFeePercent());
    }

    function holdersLotteryPrizeFeePercent() public view returns (uint256) {
        return _fees.holdersLotteryPrizeFeePercent(_calcFeePercent());
    }

    function donationLotteryPrizeFeePercent() public view returns (uint256) {
        return _fees.donationLotteryPrizeFeePercent(_calcFeePercent());
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) external view returns (bool) {
        return _isExcludedFromReward[account];
    }

    function smashTimeLotteryEnabled() external view returns (bool) {
        return _lotteryConfig.smashTimeLotteryEnabled;
    }

    function smashTimeLotteryConversionThreshold() external view returns (uint256) {
        return _lotteryConfig.smashTimeLotteryConversionThreshold;
    }

    function holdersLotteryEnabled() external view returns (bool) {
        return _lotteryConfig.holdersLotteryEnabled;
    }

    function holdersLotteryTxTrigger() external view returns (uint64) {
        return _lotteryConfig.holdersLotteryTxTrigger;
    }

    function holdersLotteryMinPercent() external view returns (uint256) {
        return _lotteryConfig.holdersLotteryMinPercent;
    }

    function donationAddress() external view returns (address) {
        return _lotteryConfig.donationAddress;
    }

    function donationsLotteryEnabled() external view returns (bool) {
        return _lotteryConfig.donationsLotteryEnabled;
    }

    function minimumDonationEntries() external view returns (uint64) {
        return _lotteryConfig.minimumDonationEntries;
    }

    function minimalDonation() external view returns (uint256) {
        return _lotteryConfig.minimalDonation;
    }

    function donationConversionThreshold() external view returns (uint256) {
        return _lotteryConfig.donationConversionThreshold;
    }

    function subscriptionId() external view returns (uint64) {
        return _consumerConfig.subscriptionId;
    }

    function callbackGasLimit() external view returns (uint32) {
        return _consumerConfig.callbackGasLimit;
    }

    function requestConfirmations() external view returns (uint16) {
        return _consumerConfig.requestConfirmations;
    }

    function gasPriceKey() external view returns (bytes32) {
        return _consumerConfig.gasPriceKey;
    }
}

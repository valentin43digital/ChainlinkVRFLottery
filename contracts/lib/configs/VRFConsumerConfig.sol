// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
	ConsumerConfig
} from "../ConstantsAndTypes.sol";

/**
	@title VRF Consumer Config
	@author shialabeoufsflag

	This contract is a component of the VRF Consumer contract, which contains
	internal logic for managing Consumer variables.
*/
abstract contract VRFConsumerConfig {

	ConsumerConfig internal _consumerConfig;

	/// Create an instance of the VRF consumer configuration contract.
	constructor (
		ConsumerConfig memory _config
	)
	{
		_consumerConfig = _config;
	}

	function _setConfig (ConsumerConfig calldata _newConfig) internal {
		_consumerConfig = _newConfig;
	}

	function _setSubscriptionId (uint64 _subscriptionId) internal {
		_consumerConfig.subscriptionId =  _subscriptionId;
	}

	function _setCallbackGasLimit (uint32 _callbackGasLimit) internal {
		_consumerConfig.callbackGasLimit =  _callbackGasLimit;
	}

	function _setRequestConfirmations (uint16 _requestConfirmations) internal {
		_consumerConfig.requestConfirmations =  _requestConfirmations;
	}

	function _setGasPriceKey (bytes32 _gasPriceKey) internal {
		_consumerConfig.gasPriceKey =  _gasPriceKey;
	}
}
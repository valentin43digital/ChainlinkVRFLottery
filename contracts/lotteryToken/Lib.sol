// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

// look for the Diamond.sol in the hardhat-deploy/solc_0.8/Diamond.sol
library Lib {
    bytes32 constant LOTTERY_TOKEN_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage.lottery_token");

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
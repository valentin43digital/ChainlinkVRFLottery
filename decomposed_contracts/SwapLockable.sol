// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

abstract contract SwapLockable {
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

    SwapStatus internal _lock = SwapStatus.Open;
}
// solhint-disable
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0 ;


interface IPegSwap {

  event LiquidityUpdated(
    uint256 amount,
    address indexed source,
    address indexed target
  );
  event TokensSwapped(
    uint256 amount,
    address indexed source,
    address indexed target,
    address indexed caller
  );
  event StuckTokensRecovered(
    uint256 amount,
    address indexed target
  );

  
  /**
   * @notice deposits tokens from the target of a swap pair but does not return
   * any. WARNING: Liquidity added through this method is only retrievable by
   * the owner of the contract.
   * @param amount count of liquidity being added
   * @param source the token that can be swapped for what is being deposited
   * @param target the token that can is being deposited for swapping
   */
  function addLiquidity(
    uint256 amount,
    address source,
    address target
  ) external;

  /**
   * @notice withdraws tokens from the target of a swap pair.
   * @dev Only callable by owner
   * @param amount count of liquidity being removed
   * @param source the token that can be swapped for what is being removed
   * @param target the token that can is being withdrawn from swapping
   */
  function removeLiquidity(
    uint256 amount,
    address source,
    address target
  ) external;

  /**
   * @notice exchanges the source token for target token
   * @param amount count of tokens being swapped
   * @param source the token that is being given
   * @param target the token that is being taken
   */
  function swap(
    uint256 amount,
    address source,
    address target
  ) external;

  /**
   * @notice returns the amount of tokens for a pair that are available to swap
   * @param source the token that is being given
   * @param target the token that is being taken
   * @return amount count of tokens available to swap
   */
  function getSwappableAmount(
    address source,
    address target
  ) external view returns(uint256 amount);

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILetVRFCoordinatorV2Interface {

  /**
   * @notice Returns the global config that applies to all VRF requests.
   * @return minimumRequestBlockConfirmations - A minimum number of confirmation
   * blocks on VRF requests before oracles should respond.
   * @return fulfillmentFlatFeeLetPPM - The charge per request on top of the gas fees.
   * Its flat fee specified in millionths of Token.
   * @return maxGasLimit - The maximum gas limit supported for a fulfillRandomWords callback.
   * @return stalenessSeconds - How long we wait until we consider the ETH/LET price
   * (used for converting gas costs to LET) is stale and use `fallbackWeiPerUnitLet`
   * @return gasAfterPaymentCalculation - How much gas is used outside of the payment calculation,
   * i.e. the gas overhead of actually making the payment to oracles.
   * @return minimumSubscriptionBalance - The minimum subscription balance required to make a request. Its set to be about 300%
   * of the cost of a single request to handle in ETH/LET price between request and fulfillment time.
   * @return fallbackWeiPerUnitLet - fallback ETH/LET price in the case of a stale feed.
   */
  function getConfig()
  external
  view
  returns (
    uint16 minimumRequestBlockConfirmations,
    uint32 fulfillmentFlatFeeLetPPM,
    uint32 maxGasLimit,
    uint32 stalenessSeconds,
    uint32 gasAfterPaymentCalculation,
    uint96 minimumSubscriptionBalance,
    int256 fallbackWeiPerUnitLet
  );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with at least minimumSubscriptionBalance (see getConfig) LET
   * before making a request.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [5000, maxGasLimit].
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64  subId,
    uint16  minimumRequestConfirmations,
    uint32  callbackGasLimit,
    uint32  numWords
  )
    external
    returns (
      uint256 requestId
    );

  /**
   * @notice Create a VRF subscription.
   * @param consumers - a list of the consuming addresses if known ahead of time.
   * You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @return subId - A unique subscription id.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LET.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription(
    address[] memory consumers
  )
    external
    returns (
      uint64 subId
    );

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LET balance of the subscription in juels.
   * @return owner - Owner of the subscription
   * @return consumers - List of consumer address which are able to use this subscription.
   */
  function getSubscription(
    uint64 subId
  )
    external
    view
    returns (
      uint96 balance,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(
    uint64 subId,
    address newOwner
  )
    external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(
    uint64 subId
  )
    external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(
    uint64 subId,
    address consumer
  )
    external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(
    uint64 subId,
    address consumer
  )
    external;

  /**
   * @notice Withdraw funds from a VRF subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the withdrawn LET to
   * @param amount - How much to withdraw in juels
   */
  function defundSubscription(
    uint64 subId,
    address to,
    uint96 amount
  )
    external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LET to
   */
  function cancelSubscription(
    uint64 subId,
    address to
  )
    external;
}

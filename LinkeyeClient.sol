// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Linkeye.sol";
import "./interfaces/ENSInterface.sol";
import "./interfaces/ILetTokenInterface.sol";
import "./interfaces/ILetRequestInterface.sol";
import "./interfaces/ILetOperatorInterface.sol";
import "./interfaces/ILetPointerInterface.sol";
import {ENSResolver as ENSResolver_Linkeye} from "./vendor/ENSResolver.sol";

/**
 * @title The LinkeyeClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Linkeye network
 */
abstract contract LinkeyeClient {
  using Linkeye for Linkeye.Request;

  uint256 internal constant LET_DIVISIBILITY = 10**18;
  uint256 private constant AMOUNT_OVERRIDE = 0;
  address private constant SENDER_OVERRIDE = address(0);
  uint256 private constant ORACLE_ARGS_VERSION = 1;
  uint256 private constant OPERATOR_ARGS_VERSION = 2;
  bytes32 private constant ENS_TOKEN_SUBNAME = keccak256("let");
  bytes32 private constant ENS_ORACLE_SUBNAME = keccak256("oracle");
  address private constant LET_TOKEN_POINTER = 0xffffffffffffffffffffffffffffffffffffffff; //replace the real address of let later

  ENSInterface private s_ens;
  bytes32 private s_ensNode;
  ILetTokenInterface private s_let;
  ILetOperatorInterface private s_oracle;
  uint256 private s_requestCount = 1;
  mapping(bytes32 => address) private s_pendingRequests;

  event LinkeyeRequested(bytes32 indexed id);
  event LinkeyeFulfilled(bytes32 indexed id);
  event LinkeyeCancelled(bytes32 indexed id);

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackAddr address to operate the callback on
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Linkeye Request struct in memory
   */
  function buildLinkeyeRequest(
    bytes32 specId,
    address callbackAddr,
    bytes4 callbackFunctionSignature
  ) internal pure returns (Linkeye.Request memory) {
    Linkeye.Request memory req;
    return req.initialize(specId, callbackAddr, callbackFunctionSignature);
  }

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Linkeye Request struct in memory
   */
  function buildOperatorRequest(bytes32 specId, bytes4 callbackFunctionSignature)
    internal
    view
    returns (Linkeye.Request memory)
  {
    Linkeye.Request memory req;
    return req.initialize(specId, address(this), callbackFunctionSignature);
  }

  /**
   * @notice Creates a Linkeye request to the stored oracle address
   * @dev Calls `linkeyeRequestTo` with the stored oracle address
   * @param req The initialized Linkeye Request
   * @param payment The amount of LET to send for the request
   * @return requestId The request ID
   */
  function sendLinkeyeRequest(Linkeye.Request memory req, uint256 payment) internal returns (bytes32) {
    return sendLinkeyeRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Linkeye request to the specified oracle address
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LET which creates a request on the target oracle contract.
   * Emits LinkeyeRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Linkeye Request
   * @param payment The amount of LET to send for the request
   * @return requestId The request ID
   */
  function sendLinkeyeRequestTo(
    address oracleAddress,
    Linkeye.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      ILetRequestInterface.oracleRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LET sent
      req.id,
      address(this),
      req.callbackFunctionId,
      nonce,
      ORACLE_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Creates a Linkeye request to the stored oracle address
   * @dev This function supports multi-word response
   * @dev Calls `sendOperatorRequestTo` with the stored oracle address
   * @param req The initialized Linkeye Request
   * @param payment The amount of LET to send for the request
   * @return requestId The request ID
   */
  function sendOperatorRequest(Linkeye.Request memory req, uint256 payment) internal returns (bytes32) {
    return sendOperatorRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Linkeye request to the specified oracle address
   * @dev This function supports multi-word response
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LET which creates a request on the target oracle contract.
   * Emits LinkeyeRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Linkeye Request
   * @param payment The amount of LET to send for the request
   * @return requestId The request ID
   */
  function sendOperatorRequestTo(
    address oracleAddress,
    Linkeye.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      ILetOperatorInterface.operatorRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LET sent
      req.id,
      req.callbackFunctionId,
      nonce,
      OPERATOR_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Make a request to an oracle
   * @param oracleAddress The address of the oracle for the request
   * @param nonce used to generate the request ID
   * @param payment The amount of LET to send for the request
   * @param encodedRequest data encoded for request type specific format
   * @return requestId The request ID
   */
  function _rawRequest(
    address oracleAddress,
    uint256 nonce,
    uint256 payment,
    bytes memory encodedRequest
  ) private returns (bytes32 requestId) {
    requestId = keccak256(abi.encodePacked(this, nonce));
    s_pendingRequests[requestId] = oracleAddress;
    emit LinkeyeRequested(requestId);
    require(s_let.transferAndCall(oracleAddress, payment, encodedRequest), "unable to transferAndCall to oracle");
  }

  /**
   * @notice Allows a request to be cancelled if it has not been fulfilled
   * @dev Requires keeping track of the expiration value emitted from the oracle contract.
   * Deletes the request from the `pendingRequests` mapping.
   * Emits LinkeyeCancelled event.
   * @param requestId The request ID
   * @param payment The amount of LET sent for the request
   * @param callbackFunc The callback function specified for the request
   * @param expiration The time of the expiration for the request
   */
  function cancelLinkeyeRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunc,
    uint256 expiration
  ) internal {
    ILetOperatorInterface requested = ILetOperatorInterface(s_pendingRequests[requestId]);
    delete s_pendingRequests[requestId];
    emit LinkeyeCancelled(requestId);
    requested.cancelOracleRequest(requestId, payment, callbackFunc, expiration);
  }

  /**
   * @notice the next request count to be used in generating a nonce
   * @dev starts at 1 in order to ensure consistent gas cost
   * @return returns the next request count to be used in a nonce
   */
  function getNextRequestCount() internal view returns (uint256) {
    return s_requestCount;
  }

  /**
   * @notice Sets the stored oracle address
   * @param oracleAddress The address of the oracle contract
   */
  function setLinkeyeOracle(address oracleAddress) internal {
    s_oracle = ILetOperatorInterface(oracleAddress);
  }

  /**
   * @notice Sets the LET token address
   * @param letAddress The address of the LET token contract
   */
  function setLinkeyeToken(address letAddress) internal {
    s_let = ILetTokenInterface(letAddress);
  }

  /**
   * @notice Sets the Linkeye token address for the public
   * network as given by the Pointer contract
   */
  function setPublicLinkeyeToken() internal {
    setLinkeyeToken(ILetPointerInterface(LET_TOKEN_POINTER).getAddress());
  }

  /**
   * @notice Retrieves the stored address of the LET token
   * @return The address of the LET token
   */
  function linkeyeTokenAddress() internal view returns (address) {
    return address(s_let);
  }

  /**
   * @notice Retrieves the stored address of the oracle contract
   * @return The address of the oracle contract
   */
  function linkeyeOracleAddress() internal view returns (address) {
    return address(s_oracle);
  }

  /**
   * @notice Allows for a request which was created on another contract to be fulfilled
   * on this contract
   * @param oracleAddress The address of the oracle contract that will fulfill the request
   * @param requestId The request ID used for the response
   */
  function addLinkeyeExternalRequest(address oracleAddress, bytes32 requestId) internal notPendingRequest(requestId) {
    s_pendingRequests[requestId] = oracleAddress;
  }

  /**
   * @notice Sets the stored oracle and LET token contracts with the addresses resolved by ENS
   * @dev Accounts for subnodes having different resolvers
   * @param ensAddress The address of the ENS contract
   * @param node The ENS node hash
   */
  function useLinkeyeWithENS(address ensAddress, bytes32 node) internal {
    s_ens = ENSInterface(ensAddress);
    s_ensNode = node;
    bytes32 letSubnode = keccak256(abi.encodePacked(s_ensNode, ENS_TOKEN_SUBNAME));
    ENSResolver_Linkeye resolver = ENSResolver_Linkeye(s_ens.resolver(letSubnode));
    setLinkeyeToken(resolver.addr(letSubnode));
    updateLinkeyeOracleWithENS();
  }

  /**
   * @notice Sets the stored oracle contract with the address resolved by ENS
   * @dev This may be called on its own as long as `useLinkeyeWithENS` has been called previously
   */
  function updateLinkeyeOracleWithENS() internal {
    bytes32 oracleSubnode = keccak256(abi.encodePacked(s_ensNode, ENS_ORACLE_SUBNAME));
    ENSResolver_Linkeye resolver = ENSResolver_Linkeye(s_ens.resolver(oracleSubnode));
    setLinkeyeOracle(resolver.addr(oracleSubnode));
  }

  /**
   * @notice Ensures that the fulfillment is valid for this contract
   * @dev Use if the contract developer prefers methods instead of modifiers for validation
   * @param requestId The request ID for fulfillment
   */
  function validateLinkeyeCallback(bytes32 requestId)
    internal
    recordLinkeyeFulfillment(requestId)
  // solhint-disable-next-line no-empty-blocks
  {

  }

  /**
   * @dev Reverts if the sender is not the oracle of the request.
   * Emits LinkeyeFulfilled event.
   * @param requestId The request ID for fulfillment
   */
  modifier recordLinkeyeFulfillment(bytes32 requestId) {
    require(msg.sender == s_pendingRequests[requestId], "Source must be the oracle of the request");
    delete s_pendingRequests[requestId];
    emit LinkeyeFulfilled(requestId);
    _;
  }

  /**
   * @dev Reverts if the request is already pending
   * @param requestId The request ID for fulfillment
   */
  modifier notPendingRequest(bytes32 requestId) {
    require(s_pendingRequests[requestId] == address(0), "Request is already pending");
    _;
  }
}
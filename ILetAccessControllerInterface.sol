// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILetAccessControllerInterface {
  function hasAccess(address user, bytes calldata data) external view returns (bool);
}

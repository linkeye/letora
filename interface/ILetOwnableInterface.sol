// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILetOwnableInterface {
  function owner()
    external
    returns (
      address
    );

  function transferOwnership(
    address recipient
  )
    external;

  function acceptOwnership()
    external;
}

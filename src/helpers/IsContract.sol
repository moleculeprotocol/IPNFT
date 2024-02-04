// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

function isContract(address _addr) view returns (bool) {
  uint32 size;
  assembly {
    size := extcodesize(_addr)
  }
  return (size > 0);
}

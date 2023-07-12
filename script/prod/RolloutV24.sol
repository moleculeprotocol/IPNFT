// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';
import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { IPNFT } from '../../src/IPNFT.sol';
import { IPermissioner, TermsAcceptedPermissioner } from '../../src/Permissioner.sol';
import { Synthesizer } from '../../src/Synthesizer.sol';
import { StakedLockingCrowdSale } from '../../src/crowdsale/StakedLockingCrowdSale.sol';
import { SignedMintAuthorizer } from '../../src/SignedMintAuthorizer.sol';

contract RolloutV24 is Script {
  function run() public {
    vm.startBroadcast();
    // IPNFT ipnftImpl = new IPNFT();
    address goerliDefenderRelayer = 0xbCeb6b875513629eFEDeF2A2D0b2f2a8fd2D4Ea4;
    SignedMintAuthorizer authorizer = new SignedMintAuthorizer(
      goerliDefenderRelayer
    );

    vm.stopBroadcast();
    console.log('Authorizer implementation: %s', address(authorizer));
    // console.log("ipnft implementation: %s", address(ipnftImpl));
  }
}

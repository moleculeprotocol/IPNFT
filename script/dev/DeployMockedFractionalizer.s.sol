// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { DeployFractionalizerL2 } from "../DeployFractionalizerL2.s.sol";
import { MockCrossDomainMessenger } from "../../test/helpers/MockCrossDomainMessenger.sol";
import { Fractionalizer } from "../../src/Fractionalizer.sol";

contract TestableFractionalizer is Fractionalizer {
    constructor(address trustedForwarder) Fractionalizer(trustedForwarder) { }

    function __dangerouslyOverrideXDomainMessenger(address _testMessenger) public {
        crossDomainMessenger = ICrossDomainMessenger(_testMessenger);
    }
}

//deploys contracts that allow calling the Fractionalizer's methods directly
contract DeployMockedFractionalizer is Script {
    function run() public {
        vm.startBroadcast();
        address callingContract = vm.addr(uint256(0xc70c8b077120));

        MockCrossDomainMessenger xDomainMessenger = new MockCrossDomainMessenger();
        xDomainMessenger.setSender(callingContract);

        TestableFractionalizer fractionalizer = TestableFractionalizer(
            address(
                new ERC1967Proxy(
                    address(
                        new TestableFractionalizer(address(0))
                    ), ""
                )
            )
        );
        fractionalizer.initialize();
        fractionalizer.__dangerouslyOverrideXDomainMessenger(address(xDomainMessenger));
        fractionalizer.setFractionalizerDispatcherL1(callingContract);

        console.log("mock xdomain messenger %s", address(xDomainMessenger));
        console.log("fractionalizer l2 %s", address(fractionalizer));

        vm.stopBroadcast();
    }
}

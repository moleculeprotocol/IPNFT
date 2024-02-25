// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

import { IPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";
import { CrowdSale } from "../src/crowdsale/CrowdSale.sol";
import { StakedLockingCrowdSale } from "../src/crowdsale/StakedLockingCrowdSale.sol";
import { ITokenVesting, ROLE_CREATE_SCHEDULE } from "../src/ITokenVesting.sol";


contract DeployPeriphery is Script {
    function run() public {
        vm.startBroadcast();
        IPermissioner p = new TermsAcceptedPermissioner();
        vm.stopBroadcast();

        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(p));
    }
}

contract DeployCrowdSale is Script {
    function run() public {
        vm.startBroadcast();
        CrowdSale crowdSale = new CrowdSale();
        crowdSale.setCurrentFeesBp(1000);
        console.log("PLAIN_CROWDSALE_ADDRESS=%s", address(crowdSale));
    }
}

/**
 * @title deploy crowdSale
 * @author
 */
contract DeployStakedCrowdSale is Script {
    function run() public {
        vm.startBroadcast();
        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale();       
        vm.stopBroadcast();

        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
    }
}


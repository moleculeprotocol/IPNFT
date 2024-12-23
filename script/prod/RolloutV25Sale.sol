// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";
import { LockingCrowdSale } from "../../src/crowdsale/LockingCrowdSale.sol";
import { TimelockedToken } from "../../src/TimelockedToken.sol";

contract RolloutV25Sale is Script {
    function run() public {
        address moleculeDevMultisig = 0xCfA0F84660fB33bFd07C369E5491Ab02C449f71B;
        vm.startBroadcast();

        TimelockedToken timelockedTokenImplementation = new TimelockedToken();
        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale(timelockedTokenImplementation);
        stakedLockingCrowdSale.transferOwnership(moleculeDevMultisig);
        vm.stopBroadcast();

        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
        console.log("timelocked token implementation=%s", address(timelockedTokenImplementation));
        // 0x7c36c64DA1c3a2065074caa9C48e7648FB733aAB
        // vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        // stakedLockingCrowdSale.trustVestingContract(vestedDaoToken);
    }
}

contract RolloutV25LockingSale is Script {
    function run() public {
        //mainnet 0xCfA0F84660fB33bFd07C369E5491Ab02C449f71B;
        address moleculeDevMultisig = 0x9d5a6ae551f1117946FF6e0e86ef9A1B20C90Cb0;
        
        TimelockedToken timelockedTokenImplementation = TimelockedToken(0xF8F79c1E02387b0Fc9DE0945cD9A2c06F127D851); 

        vm.startBroadcast();
        LockingCrowdSale lockingCrowdsale = new LockingCrowdSale(timelockedTokenImplementation);
        lockingCrowdsale.transferOwnership(moleculeDevMultisig);
        vm.stopBroadcast();

        console.log("LOCKING_CROWDSALE_ADDRESS=%s", address(lockingCrowdsale));
        console.log("timelocked token implementation=%s", address(timelockedTokenImplementation));
        // 0x7c36c64DA1c3a2065074caa9C48e7648FB733aAB
        // vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        // stakedLockingCrowdSale.trustVestingContract(vestedDaoToken);
    }
}
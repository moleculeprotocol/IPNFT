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
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

TimelockedToken constant timelockedTokenImplementation = TimelockedToken(0x625ed621d814645AA81C50c4f333D4a407576e8F); 

address constant moleculeDevMultisig = 0xCfA0F84660fB33bFd07C369E5491Ab02C449f71B;

contract DeployTimelockedTokenTemplate is Script {
    function run() public {
        vm.startBroadcast();
        TimelockedToken impl = new TimelockedToken();
        impl.initialize(IERC20Metadata(address(0x0)));
        vm.stopBroadcast();

        console.log("timelocked token implementation=%s", address(impl));
    }
}

contract RolloutV25LockingSale is Script {
    function run() public {
    
        vm.startBroadcast();
        LockingCrowdSale lockingCrowdsale = new LockingCrowdSale(timelockedTokenImplementation);
        //lockingCrowdsale.transferOwnership(moleculeDevMultisig);
        vm.stopBroadcast();

        console.log("LOCKING_CROWDSALE_ADDRESS=%s", address(lockingCrowdsale));
        console.log("timelocked token implementation=%s", address(timelockedTokenImplementation));
    }
}


contract RolloutV25StakedSale is Script {
    function run() public {

        TokenVesting vesting = TokenVesting(0x8f80d1183CD983B01B0C9AC6777cC732Ec9800de); //Moldao
        
        vm.startBroadcast();
        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale(timelockedTokenImplementation);
        vesting.grantRole(vesting.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        //stakedLockingCrowdSale.trustLockingContract(IERC20());
        stakedLockingCrowdSale.trustVestingContract(vesting);
//        stakedLockingCrowdSale.transferOwnership(moleculeDevMultisig);
        vm.stopBroadcast();

        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
        console.log("timelocked token implementation=%s", address(timelockedTokenImplementation));
        // 0x7c36c64DA1c3a2065074caa9C48e7648FB733aAB
        // vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        // stakedLockingCrowdSale.trustVestingContract(vestedDaoToken);
    }
}
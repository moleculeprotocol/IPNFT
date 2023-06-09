// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { Synthesizer } from "../../src/Synthesizer.sol";
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";

contract RolloutV23 is Script {
    function run() public {
        address mintpass = 0x0Ecff38F41EcD1E978f1443eD96c0C22497d73cB;
        //address vestedDaoToken = 0x0
        address moleculeDevMultisig = 0xCfA0F84660fB33bFd07C369E5491Ab02C449f71B;
        vm.startBroadcast();
        IPNFT ipnftImpl = new IPNFT();

        IPNFT ipnft = IPNFT(address(new ERC1967Proxy(address(ipnftImpl), "")));

        ipnft.initialize();
        ipnft.setAuthorizer(mintpass);
        ipnft.transferOwnership(moleculeDevMultisig);

        IPermissioner permissioner = new TermsAcceptedPermissioner();
        Synthesizer synthImpl = new Synthesizer();

        Synthesizer synthesizer = Synthesizer(
            address(
                new ERC1967Proxy(
                    address(synthImpl), ""
                )
            )
        );
        synthesizer.initialize(ipnft, permissioner);
        synthesizer.transferOwnership(moleculeDevMultisig);

        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale();
        //if we have vesting contracts:
        //stakedLockingCrowdSale.trustVestingContract(vestedDaoToken);
        //will work after merging:
        stakedLockingCrowdSale.transferOwnership(moleculeDevMultisig);

        //tell the tokenvesting owner to then execute:
        // TokenVesting vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));
        // vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        vm.stopBroadcast();

        console.log("IPNFT_ADDRESS=%s", address(ipnft));
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(permissioner));
        console.log("SYNTHESIZER_ADDRESS=%s", address(synthesizer));
        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));

        console.log("synthImpl implementation: %s", address(synthImpl));
        console.log("ipnft implementation: %s", address(ipnftImpl));
    }
}

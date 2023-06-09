// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Synthesizer } from "../src/Synthesizer.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BioPriceFeed } from "../src/BioPriceFeed.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";
import { StakedLockingCrowdSale } from "../src/crowdsale/StakedLockingCrowdSale.sol";

contract DeploySynthesizerInfrastructure is Script {
    function run() public {
        vm.startBroadcast();
        address ipnftAddress = vm.envAddress("IPNFT_ADDRESS");
        BioPriceFeed feed = new BioPriceFeed();
        IPermissioner p = new TermsAcceptedPermissioner();

        Synthesizer synthesizer = Synthesizer(
            address(
                new ERC1967Proxy(
                    address(new Synthesizer()), ""
                )
            )
        );
        synthesizer.initialize(IPNFT(ipnftAddress), p);

        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale();

        vm.stopBroadcast();

        console.log("PRICEFEED_ADDRESS=%s", address(feed));
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(p));
        console.log("SYNTHESIZER_ADDRESS=%s", address(synthesizer));
        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
    }
}

contract DeploySynthesizerImplementation is Script {
    function run() public {
        vm.startBroadcast();
        Synthesizer impl = new Synthesizer();
        vm.stopBroadcast();

        console.log("synthesizer impl %s", address(impl));
    }
}

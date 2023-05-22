// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BioPriceFeed } from "../src/BioPriceFeed.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";
import { StakedVestedCrowdSale } from "../src/crowdsale/StakedVestedCrowdSale.sol";

contract DeployFractionalizerInfrastructure is Script {
    function run() public {
        vm.startBroadcast();
        address ipnftAddress = vm.envAddress("IPNFT_ADDRESS");
        //address sosAddress = vm.envAddress("SOS_ADDRESS");

        BioPriceFeed feed = new BioPriceFeed();
        IPermissioner p = new TermsAcceptedPermissioner();

        Fractionalizer fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(new Fractionalizer()), ""
                )
            )
        );
        fractionalizer.initialize(IPNFT(ipnftAddress));

        StakedVestedCrowdSale stakedVestedCrowdSale = new StakedVestedCrowdSale();

        vm.stopBroadcast();

        console.log("PRICEFEED_ADDRESS=%s", address(feed));
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(p));
        console.log("FRACTIONALIZER_ADDRESS=%s", address(fractionalizer));
        console.log("STAKED_VESTED_CROWDSALE_ADDRESS=%s", address(stakedVestedCrowdSale));
    }
}

contract DeployFractionalizerImplementation is Script {
    function run() public {
        vm.startBroadcast();
        Fractionalizer impl = new Fractionalizer();
        vm.stopBroadcast();

        console.log("fractionalizer impl %s", address(impl));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Tokenizer } from "../src/Tokenizer.sol";
import { IPToken } from "../src/IPToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BioPriceFeed } from "../src/BioPriceFeed.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../src/Permissioner.sol";
import { CrowdSale } from "../src/crowdsale/CrowdSale.sol";
import { StakedLockingCrowdSale } from "../src/crowdsale/StakedLockingCrowdSale.sol";

contract DeployTokenizerInfrastructure is Script {
    function run() public {
        vm.startBroadcast();
        address ipnftAddress = vm.envAddress("IPNFT_ADDRESS");
        IPermissioner permissioner = new TermsAcceptedPermissioner();

        Tokenizer tokenizer = Tokenizer(
            address(
                address(new ERC1967Proxy(address(new Tokenizer()), abi.encodeWithSelector(Tokenizer.initialize.selector, ipnftAddress, permissioner)))
            )
        );
        IPToken initialIpTokenImplementation = new IPToken();
        tokenizer.setIPTokenImplementation(initialIpTokenImplementation);

        CrowdSale crowdSale = new CrowdSale();
        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale();
        vm.stopBroadcast();

        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(permissioner));
        console.log("TOKENIZER_ADDRESS=%s", address(tokenizer));
        console.log("CROWDSALE_ADDRESS=%s", address(crowdSale));
        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
        console.log("initial IP Token implementation=%s", address(initialIpTokenImplementation));
    }
}

contract DeploytokenizerImplementation is Script {
    function run() public {
        vm.startBroadcast();
        Tokenizer impl = new Tokenizer();
        vm.stopBroadcast();

        console.log("tokenizer impl %s", address(impl));
    }
}

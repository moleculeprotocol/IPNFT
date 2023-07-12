// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { SignedMintAuthorizer } from "../src/SignedMintAuthorizer.sol";

/**
 * @title DeploySuite
 * @author molecule.to
 * @notice deploys IPNFT, Authorizer, Schmackoswap, initializes IPNFT with signature expecting authorizer
 */
contract DeploySuite is Script {
    function run() public {
        address moderator = vm.envAddress("MODERATOR_ADDRESS");
        vm.startBroadcast();
        IPNFT implementation = new IPNFT();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), "");
        IPNFT ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        SchmackoSwap swap = new SchmackoSwap();
        SignedMintAuthorizer authorizer = new SignedMintAuthorizer(moderator);
        ipnft.setAuthorizer(authorizer);

        console.log("IPNFT_ADDRESS=%s", address(ipnft));
        console.log("SOS_ADDRESS=%s", address(swap));
        console.log("AUTHORIZER_ADDRESS=%s", address(authorizer));

        vm.stopBroadcast();
    }
}

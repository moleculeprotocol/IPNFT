// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { IPNFTV21 } from "../src/IPNFTV21.sol";
import { IPNFTV22 } from "../src/IPNFTV22.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract IPNFTUpgradesV22 is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);

    UUPSProxy proxy;
    IPNFT internal ipnft;
    IPNFTV21 internal ipnftV21;
    IPNFTV22 internal ipnftV22;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        vm.stopPrank();
    }

    function doUpgrade() public {
        IPNFTV21 implementationV21 = new IPNFTV21();
        ipnft.upgradeTo(address(implementationV21));

        IPNFTV22 implementationV22 = new IPNFTV22();
        ipnft.upgradeTo(address(implementationV22));
        ipnftV22 = IPNFTV22(address(proxy));
        ipnftV22.reinit();
    }

    function testUpgradeToV22() public {
        vm.startPrank(deployer);
        doUpgrade();
        assertEq(ipnftV22.totalSupply(0), 0);

        vm.expectRevert("Initializable: contract is already initialized");
        ipnftV22.initialize();

        vm.expectRevert("Initializable: contract is already initialized");
        ipnftV22.reinit();
        vm.stopPrank();

        assertEq(ipnftV22.aNewProperty(), "some property");
    }

    function testTokensSurviveUpgrade() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        doUpgrade();
        vm.stopPrank();

        assertEq(ipnftV22.totalSupply(1), 1);
        assertEq(ipnftV22.balanceOf(alice, 1), 1);
    }

    function testLosesPauseability() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        ipnft.pause();
        doUpgrade();
        vm.stopPrank();

        dealMintpass(bob);

        vm.startPrank(bob);
        //can reserve even though it was supposed to fail when paused before
        ipnftV22.reserve();
        vm.stopPrank();
    }
}

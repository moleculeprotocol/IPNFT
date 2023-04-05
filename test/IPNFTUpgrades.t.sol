// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { IPNFTV23 } from "../src/IPNFTV23.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract IPNFTUpgrades is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);

    UUPSProxy proxy;
    IPNFT internal ipnft;
    IPNFTV23 internal ipnftV23;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV21 = new IPNFT();
        proxy = new UUPSProxy(address(implementationV21), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        vm.stopPrank();
        vm.deal(alice, 0.05 ether);
    }

    function doUpgrade() public {
        IPNFTV23 implementationV22 = new IPNFTV23();
        ipnft.upgradeTo(address(implementationV22));

        ipnftV23 = IPNFTV23(address(proxy));
        ipnftV23.reinit();
    }

    function testUpgradeContract() public {
        vm.startPrank(deployer);
        doUpgrade();
        assertEq(ipnftV23.totalSupply(0), 0);

        vm.expectRevert("Initializable: contract is already initialized");
        ipnftV23.initialize();

        vm.stopPrank();
        assertEq(ipnftV23.aNewProperty(), "some property");
    }

    function testTokensSurviveUpgrade() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        doUpgrade();
        vm.stopPrank();

        assertEq(ipnftV23.totalSupply(1), 1);
        assertEq(ipnftV23.balanceOf(alice, 1), 1);
        assertEq(ipnftV23.symbol(1), DEFAULT_SYMBOL);
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
        ipnftV23.reserve();
        vm.stopPrank();
    }
}

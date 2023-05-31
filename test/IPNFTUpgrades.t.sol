// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { IPNFTV24 } from "../src/helpers/upgrades/IPNFTV24.sol";

contract IPNFTUpgrades is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);

    IPNFT internal ipnft;
    IPNFTV24 internal ipnftV24;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV23 = new IPNFT();
        ipnft = IPNFT(address(new ERC1967Proxy(address(implementationV23), "")));
        ipnft.initialize();

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        vm.stopPrank();
        vm.deal(alice, 0.05 ether);
    }

    function doUpgrade() public {
        IPNFTV24 implementationV24 = new IPNFTV24();
        ipnft.upgradeTo(address(implementationV24));

        ipnftV24 = IPNFTV24(address(ipnft));
        ipnftV24.reinit();
    }

    function testUpgradeContract() public {
        vm.startPrank(deployer);
        doUpgrade();
        //assertEq(ipnft.totalSupply(0), 0);

        vm.expectRevert("Initializable: contract is already initialized");
        ipnftV24.initialize();

        vm.stopPrank();
        assertEq(ipnftV24.aNewProperty(), "some property");
    }

    function testTokensSurviveUpgrade() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        doUpgrade();
        vm.stopPrank();

        assertEq(ipnftV24.ownerOf(1), alice);
        assertEq(ipnftV24.symbol(1), DEFAULT_SYMBOL);
    }

    function testKeepsPauseability() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        ipnft.pause();
        doUpgrade();
        vm.stopPrank();

        dealMintpass(bob);

        vm.startPrank(bob);
        //can reserve even though it was supposed to fail when paused before
        vm.expectRevert("Pausable: paused");
        ipnftV24.reserve();
        vm.stopPrank();
    }
}

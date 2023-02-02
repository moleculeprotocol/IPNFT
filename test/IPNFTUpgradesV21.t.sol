// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { IPNFTV21 } from "../src/IPNFTV21.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract IPNFTUpgradesV21 is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);

    UUPSProxy proxy;
    IPNFT internal ipnft;
    IPNFTV21 internal ipnftV21;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

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

        ipnftV21 = IPNFTV21(address(proxy));
    }

    function testUpgradeContract() public {
        vm.startPrank(deployer);
        doUpgrade();
        assertEq(ipnftV21.totalSupply(0), 0);

        vm.expectRevert("Initializable: contract is already initialized");
        ipnftV21.initialize();
        vm.stopPrank();
    }

    function testTokensSurviveUpgrade() public {
        mintAToken(ipnft, alice);

        vm.startPrank(deployer);
        doUpgrade();
        vm.stopPrank();

        assertEq(ipnftV21.totalSupply(1), 1);
        assertEq(ipnftV21.balanceOf(alice, 1), 1);
    }

    function testV21RequiresMintingFee() public {
        vm.startPrank(deployer);
        doUpgrade();
        vm.stopPrank();

        dealMintpass(alice);

        vm.startPrank(alice);
        uint256 reservationId = ipnft.reserve();

        vm.expectRevert(IPNFTV21.MintingFeeTooLow.selector);
        ipnftV21.mintReservation(alice, reservationId, reservationId, arUri);

        vm.deal(alice, 0.05 ether);
        ipnftV21.mintReservation{value: 0.001 ether}(alice, reservationId, reservationId, arUri);
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { IPNFTV23 } from "../src/helpers/test-upgrades/IPNFTV23.sol";
import { SignedMintAuthorizer, SignedMintAuthorization } from "../src/SignedMintAuthorizer.sol";
import { IPNFTV25 } from "../src/helpers/test-upgrades/IPNFTV25.sol";

contract IPNFTUpgrades is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event AuthorizerUpdated(address authorizer);

    IPNFTV23 internal ipnftV23;
    IPNFT internal ipnft;
    Mintpass internal mintpass;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    uint256 deployerPk;

    function setUp() public {
        (, deployerPk) = makeAddrAndKey("chucknorris");

        vm.startPrank(deployer);
        IPNFTV23 implementationV23 = new IPNFTV23();
        ipnftV23 = IPNFTV23(address(new ERC1967Proxy(address(implementationV23), "")));
        ipnftV23.initialize();

        mintpass = new Mintpass(address(ipnftV23));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnftV23.setAuthorizer(address(mintpass));
        vm.stopPrank();

        vm.deal(alice, 0.05 ether);
    }

    function doUpgrade() public {
        IPNFT implementationV24 = new IPNFT();
        ipnftV23.upgradeTo(address(implementationV24));

        ipnft = IPNFT(address(ipnftV23));
        SignedMintAuthorizer authorizer = new SignedMintAuthorizer(deployer);

        vm.expectEmit(true, true, false, false);
        emit AuthorizerUpdated(address(authorizer));
        ipnft.setAuthorizer(authorizer);
    }

    function testUpgradeContract() public {
        vm.startPrank(deployer);
        doUpgrade();
        assertEq(ipnft.balanceOf(alice), 0);

        vm.expectRevert("Initializable: contract is already initialized");
        ipnft.initialize();

        vm.stopPrank();
    }

    function testTokensSurviveUpgrade() public {
        vm.startPrank(deployer);
        mintpass.batchMint(alice, 1);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 reservationId = ipnftV23.reserve();
        ipnftV23.mintReservation{ value: MINTING_FEE }(alice, reservationId, reservationId, arUri, DEFAULT_SYMBOL);
        vm.stopPrank();

        vm.startPrank(deployer);
        doUpgrade();
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.symbol(1), DEFAULT_SYMBOL);

        vm.startPrank(alice);
        reservationId = ipnft.reserve();

        bytes32 authMessageHash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(alice, alice, reservationId, ipfsUri)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPk, authMessageHash);
        bytes memory authorization = abi.encodePacked(r, s, v);

        ipnft.mintReservation{ value: MINTING_FEE }(alice, reservationId, ipfsUri, "ALICE-42", authorization);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 2);
        assertEq(ipnft.ownerOf(2), alice);
        assertEq(ipnft.symbol(2), "ALICE-42");
    }

    function testFutureUpgrade() public {
        vm.startPrank(deployer);
        mintpass.batchMint(alice, 1);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 reservationId = ipnftV23.reserve();
        ipnftV23.mintReservation{ value: MINTING_FEE }(alice, reservationId, reservationId, arUri, DEFAULT_SYMBOL);
        vm.stopPrank();

        vm.startPrank(deployer);
        doUpgrade();

        IPNFTV25 implementationV25 = new IPNFTV25();
        ipnft.upgradeTo(address(implementationV25));
        ipnft.pause();

        IPNFTV25 ipnftV25 = IPNFTV25(address(ipnft));
        ipnftV25.reinit();

        assertEq(ipnftV25.balanceOf(alice), 1);
        assertEq(ipnftV25.ownerOf(1), alice);
        assertEq(ipnftV25.symbol(1), DEFAULT_SYMBOL);

        vm.expectRevert("Pausable: paused");
        ipnftV25.reserve();
        vm.stopPrank();

        assertEq(ipnftV25.aNewProperty(), "some property");
    }
}

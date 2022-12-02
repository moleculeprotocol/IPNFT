// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IPNFT3525V2 } from "../src/IPNFT3525V2.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

contract IPNFT3525V2Test is Test {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string tokenURI, uint256 indexed reservationId);

    /// @notice Emitted when an NFT is minted
    /// @param tokenURI the uri containing the ip metadata
    /// @param minter the minter's address
    /// @param tokenId the minted token (slot) id
    event IPNFTMinted(string tokenURI, address indexed minter, uint256 indexed tokenId);

    IPNFT3525V2 implementationV2;
    UUPSProxy proxy;
    IPNFT3525V2 ipnft;

    Mintpass mintpass;

    address deployer = makeAddr("chucknorris");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    string ipfsUri = "ipfs://QmYwAPJzv5CZsnA9LqYKXfutJzBg68";
    string arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";
    uint256 tokenPrice = 1 ether;

    function reserveAToken(address to, string memory name, string memory tokenUri) internal returns (uint256) {
        dealMintpass(to);
        vm.startPrank(to);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, name, tokenUri);
        vm.stopPrank();
        //bytes memory ipnftArgs = abi.encode(title, tokenUri);
        return reservationId;
    }

    function mintAToken(address to, string memory name, string memory tokenUri) internal returns (uint256) {
        uint256 reservationId = reserveAToken(to, name, tokenUri);
        vm.startPrank(to);
        ipnft.mintReservation(to, reservationId, 1);
        vm.stopPrank();
        return reservationId;
    }

    function dealMintpass(address to) internal returns (uint256) {
        vm.startPrank(deployer);
        mintpass.batchMint(to, 1);
        vm.stopPrank();

        return 1;
    }

    function setUp() public {
        vm.startPrank(deployer);
        implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT3525V2(address(proxy));
        ipnft.initialize();
        mintpass = new Mintpass(address(ipnft));
        ipnft.setMintpassContract(address(mintpass));
        vm.stopPrank();
    }

    function testContractName() public {
        assertEq(ipnft.name(), "IP-NFT V2");
    }

    function testTokenReservation() public {
        dealMintpass(alice);

        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit Reserved(alice, 1);
        uint256 reservationId = ipnft.reserve();
        ipnft.updateReservation(reservationId, "IP Title", arUri);

        (address reserver, string memory name, string memory tokenURI) = ipnft._reservations(1);
        assertEq(reserver, alice);
        assertEq(name, "IP Title");
        assertEq(tokenURI, arUri);
    }

    function testMintFromReservation() public {
        uint256 reservationId = reserveAToken(alice, "IP Title", arUri);
        vm.expectEmit(true, true, false, true);
        emit IPNFTMinted(arUri, alice, 1);

        vm.startPrank(alice);
        ipnft.mintReservation(alice, reservationId, 1);
        assertEq(ipnft.balanceOf(alice), 1);

        assertEq(
            ipnft.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJleHRlcm5hbF91cmwiOiJhcjovL3ROYmRIcWgzQVZESFZEMDZQME9QVVhTUHJvSTVrR2NaWnc4SXZMa2VrU1kifQ=="
        );

        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.tokenOfOwnerByIndex(alice, 0), 1);

        (address reserver,,) = ipnft._reservations(1);
        assertEq(reserver, address(0));

        // Was the Mintpass redeemed?
        assertEq(mintpass.balanceOf(alice), 1);
        assertEq(mintpass.isRedeemable(1), false);

        //status: redeemed
        assertEq(
            mintpass.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjogIklQLU5GVCBNaW50cGFzcyAjMSIsICJkZXNjcmlwdGlvbiI6ICJUaGlzIE1pbnRwYXNzIGNhbiBiZSB1c2VkIHRvIG1pbnQgb25lIElQLU5GVCIsICJleHRlcm5hbF91cmwiOiAiVE9ETzogRW50ZXIgSVAtTkZULVVJIFVSTCIsICJpbWFnZSI6ICJpcGZzOi8vaW1hZ2VUb1Nob3dXaGVuTm90UmVkZWVtYWJsZSIsICJzdGF0dXMiOiAicmVkZWVtZWQifQ=="
        );

        vm.stopPrank();
    }

    function testTokenURIUpdate() public {
        uint256 reservationId = reserveAToken(alice, "IP Title", arUri);
        //this only changes the uri.
        vm.startPrank(alice);
        ipnft.updateReservation(reservationId, "", ipfsUri);
        ipnft.mintReservation(alice, 1, 1);

        assertEq(
            ipnft.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJleHRlcm5hbF91cmwiOiJpcGZzOi8vUW1Zd0FQSnp2NUNac25BOUxxWUtYZnV0SnpCZzY4In0="
        );
        vm.stopPrank();
    }

    //todo actually alice can only burn the token
    //because she's marked as its minter. Currently only the
    //minter can burn their tokens.
    function testBurn() public {
        mintAToken(alice, "IP Title", arUri);

        vm.startPrank(alice);

        ipnft.burn(1);

        assertEq(ipnft.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testCantUpdateTokenURIOnMintedTokens() public {
        uint256 reservationId = reserveAToken(alice, "IP Title", arUri);

        vm.startPrank(alice);
        ipnft.mintReservation(bob, reservationId, 1);

        vm.expectRevert("IP-NFT: caller is not reserver");
        ipnft.updateReservation(reservationId, "Foo", "bar");
    }

    function testOnlyReservationOwnerCanMintFromReservation() public {
        uint256 reservationId = reserveAToken(alice, "IP Title", arUri);

        vm.startPrank(bob);
        vm.expectRevert("IP-NFT: caller is not reserver");
        ipnft.mintReservation(bob, reservationId, 1);
        vm.stopPrank();
    }

    function testTransferOneNft() public {
        uint256 tokenId = mintAToken(alice, "IP Title", arUri);
        assertEq(ipnft.ownerOf(tokenId), alice);
        assertEq(ipnft.balanceOf(alice), 1);

        vm.startPrank(alice);
        ipnft.safeTransferFrom(alice, bob, tokenId);
        assertEq(ipnft.ownerOf(1), bob);
        assertEq(ipnft.balanceOf(bob), 1);
        vm.stopPrank();

        //see if approvals also work
        vm.startPrank(bob);
        ipnft.approve(charlie, tokenId);

        //allowance is the fungible allowance on the value of a token.
        assertEq(ipnft.allowance(tokenId, charlie), 0);
        vm.stopPrank();

        vm.startPrank(charlie);
        ipnft.safeTransferFrom(bob, alice, tokenId);
        assertEq(ipnft.ownerOf(tokenId), alice);
        assertEq(ipnft.balanceOf(bob), 0);
        vm.stopPrank();
    }

    // //many NFTs can share the same slot
    // //hence the slot "uri" yields the "basic" token Uri
    function testSlots() public {
        uint256 tokenId = mintAToken(alice, "IP Title", arUri);

        assertEq(ipnft.slotOf(tokenId), 1);

        string memory slotUri = ipnft.slotURI(1);
        assertEq(
            slotUri,
            "data:application/json;base64,eyJuYW1lIjoiSVAgVGl0bGUiLCJleHRlcm5hbF91cmwiOiJhcjovL3ROYmRIcWgzQVZESFZEMDZQME9QVVhTUHJvSTVrR2NaWnc4SXZMa2VrU1kifQ=="
        );
    }

    function testTransferValueToANewUser() public {
        uint256 tokenId = mintAToken(alice, "IP Title", arUri);

        //this is the ERC3525 value transfer that's not available on IPNFTV2.0 / ERC721
        vm.expectRevert("not available in V2");
        vm.startPrank(alice);
        ipnft.transferFrom(tokenId, bob, 5);
        vm.stopPrank();
    }

    function testCantReserveWithoutMintpass() public {
        vm.startPrank(alice);
        vm.expectRevert("IPNFT: You need to own a mintpass to mint an IPNFT");
        ipnft.reserve();
        vm.stopPrank();
    }

    function testOnlyAdminCanSetMintpassContract() public {
        vm.startPrank(alice);
        vm.expectRevert("IP-NFT: caller is not admin");
        ipnft.setMintpassContract(address(0x5));
    }

    function testCannotMintWithoutMintpassApproval() public {
        uint256 reservationId = reserveAToken(alice, "IP Title", arUri);

        // Does Alice have the Mintpass?
        assertEq(mintpass.balanceOf(alice), 1);
        assertEq(mintpass.ownerOf(1), alice);

        vm.startPrank(deployer);
        mintpass.revoke(1);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("IPNFT: mintpass not redeemable");
        ipnft.mintReservation(alice, reservationId, 1);
        assertEq(ipnft.balanceOf(alice), 0);
        vm.stopPrank();
    }
}

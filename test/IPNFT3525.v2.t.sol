// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IPNFT3525V2 } from "../src/IPNFT3525V2.sol";
import { IPNFT, Reservation } from "../src/Structs.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { IPNFTMetadata } from "../src/IPNFTMetadata.sol";

contract IPNFT3525V2Test is IPNFTMintHelper {
    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string name, uint256 indexed reservationId);

    /// @notice Emitted when an NFT is minted
    /// @param minter the minter's address
    /// @param tokenId the minted token (slot) id
    event IPNFTMinted(address indexed minter, uint256 indexed tokenId);

    IPNFT3525V2 implementationV2;
    UUPSProxy proxy;
    IPNFT3525V2 internal ipnft;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    uint256 tokenPrice = 1 ether;

    function setUp() public {
        vm.startPrank(deployer);
        implementationV2 = new IPNFT3525V2();
        proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT3525V2(address(proxy));
        ipnft.initialize();

        ipnft.setMetadataGenerator(new IPNFTMetadata());

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
        ipnft.updateReservation(reservationId, encodedMetadata);
        (address reserver, IPNFT memory _ipnft) = ipnft._reservations(1);

        assertEq(reserver, alice);
        assertEq(_ipnft.name, "IP-NFT Test");
        assertEq(_ipnft.agreementUrl, agreementUrl);
    }

    function testMintFromReservation() public {
        uint256 reservationId = reserveAToken(ipnft, alice, encodedMetadata);

        vm.startPrank(alice);
        vm.expectEmit(true, true, false, true);
        emit IPNFTMinted(alice, 1);
        ipnft.mintReservation(alice, reservationId, 1, "");
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 1);

        assertEq(
            ipnft.tokenURI(1),
            'data:application/json,{"name":"IP-NFT Test","description":"Some Description","image":"ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU","balance":"1000000","slot":1,"properties": {"type":"IP-NFT","external_url":"https://discover.molecule.to/ipnft/1","agreement_url":"ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json","project_details_url":"ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json"}}'
        );

        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.tokenOfOwnerByIndex(alice, 0), 1);

        (address reserver,) = ipnft._reservations(1);
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
        uint256 reservationId = reserveAToken(ipnft, alice, encodedMetadata);
        vm.startPrank(alice);
        ipnft.updateReservation(reservationId, updatedMetadata);
        ipnft.mintReservation(alice, 1, 1, "");

        assertEq(
            ipnft.tokenURI(1),
            'data:application/json,{"name":"changed title","description":"Changed Description","image":"ar://abcde","balance":"1000000","slot":1,"properties": {"type":"IP-NFT","external_url":"https://discover.molecule.to/ipnft/1","agreement_url":"ar://defgh123/agree.json","project_details_url":"ipfs://mumumu/details.json"}}'
        );
        vm.stopPrank();
    }

    // //todo actually alice can only burn the token
    // //because she's marked as its minter. Currently only the
    // //minter can burn their tokens.
    function testBurn() public {
        mintAToken(ipnft, alice);

        vm.startPrank(alice);

        ipnft.burn(1);

        assertEq(ipnft.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function testCannotUpdateTokenURIOnMintedTokens() public {
        uint256 reservationId = reserveAToken(ipnft, alice, encodedMetadata);

        vm.startPrank(alice);
        ipnft.mintReservation(bob, reservationId, 1, "");

        vm.expectRevert(abi.encodeWithSelector(IPNFT3525V2.NotOwningReservation.selector, 1));
        ipnft.updateReservation(reservationId, updatedMetadata);
    }

    function testOnlyReservationOwnerCanMintFromReservation() public {
        uint256 reservationId = reserveAToken(ipnft, alice, encodedMetadata);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPNFT3525V2.NotOwningReservation.selector, 1));
        ipnft.mintReservation(bob, reservationId, 1, "");
        vm.stopPrank();
    }

    function testTransferOneNft() public {
        uint256 tokenId = mintAToken(ipnft, alice);
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

    // // //many NFTs can share the same slot
    // // //hence the slot "uri" yields the "basic" token Uri
    function testSlots() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        assertEq(ipnft.slotOf(tokenId), 1);

        string memory slotUri = ipnft.slotURI(1);
        assertEq(
            slotUri,
            'data:application/json,{"name":"IP-NFT Test","description":"Some Description","image":"ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU","properties": [{"name":"agreement_url","description":"agreement","display_type":"url","value":"ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json"},{"name":"project_details_url","description":"project","display_type":"url","value":"ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json"}]}'
        );
    }

    function testTransferValueToANewUser() public {
        uint256 tokenId = mintAToken(ipnft, alice);

        //this is the ERC3525 value transfer that's not available on IPNFTV2.0 / ERC721
        vm.expectRevert("not available in V2");
        vm.startPrank(alice);
        ipnft.transferFrom(tokenId, bob, 5);
        vm.stopPrank();
    }

    function testCantReserveWithoutMintpass() public {
        vm.startPrank(alice);
        vm.expectRevert(IPNFT3525V2.NeedsMintpass.selector);
        ipnft.reserve();
        vm.stopPrank();
    }

    function testOnlyAdminCanSetMintpassContract() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        ipnft.setMintpassContract(address(0x5));
    }

    function testCannotMintWithoutMintpassApproval() public {
        uint256 reservationId = reserveAToken(ipnft, alice, encodedMetadata);

        // Does Alice have the Mintpass?
        assertEq(mintpass.balanceOf(alice), 1);
        assertEq(mintpass.ownerOf(1), alice);

        vm.startPrank(alice);

        // Revoke mintpass token approval
        mintpass.approve(address(0), 1);

        vm.expectRevert("Not authorized to burn this token");
        ipnft.mintReservation(alice, reservationId, 1, "");
        assertEq(ipnft.balanceOf(alice), 0);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { Fractionalizer, Fractionalized, ToZeroAddress } from "../src/Fractionalizer.sol";
import { FractionalizedToken } from "../src/FractionalizedToken.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { MyToken } from "../src/MyToken.sol";

contract FractionalizerTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address escrow = makeAddr("escrow");

    IPNFT internal ipnft;
    Fractionalizer internal fractionalizer;
    SchmackoSwap internal schmackoSwap;

    IERC20 internal erc20;

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        MyToken myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        Mintpass mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        mintpass.batchMint(originalOwner, 1);

        fractionalizer = Fractionalizer(address(new ERC1967Proxy(address(new Fractionalizer()), "")));
        fractionalizer.initialize(ipnft, schmackoSwap);
        fractionalizer.setFeeReceiver(protocolOwner);

        vm.stopPrank();

        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation(originalOwner, reservationId, 1, ipfsUri);
        vm.stopPrank();
    }

    function testCannotSetInfraToZero() public {
        vm.startPrank(deployer);
        vm.expectRevert(ToZeroAddress.selector);
        fractionalizer.setFeeReceiver(address(0));
        vm.stopPrank();
    }

    function testIssueFractions() public {
        vm.startPrank(originalOwner);
        //ipnft.setApprovalForAll(address(fractionalizer), true);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 100_000);
        //the original nft *stays* at the owner
        assertEq(ipnft.balanceOf(originalOwner, 1), 1);

        (, uint256 totalIssued,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 100_000);

        vm.startPrank(originalOwner);
        tokenContract.transfer(alice, 10_000);

        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 10_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 90_000);
        assertEq(fractionalizer.totalSupply(fractionId), 100_000);
    }

    function testIncreaseFractions() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (, uint256 totalIssued,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);

        tokenContract.transfer(alice, 25_000);
        tokenContract.transfer(bob, 25_000);

        fractionalizer.increaseFractions(fractionId, 100_000);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(bob, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 150_000);
        assertEq(fractionalizer.totalSupply(fractionId), 200_000);

        (, totalIssued,,,,,,) = fractionalizer.fractionalized(fractionId);

        (, totalIssued,,,,,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 200_000);
    }

    /*
    function testCanBeFractionalizedOnlyOnce() public {
        uint256 fractionId = helpInitializeFractions();

        vm.expectRevert("token is already fractionalized");
        fractionalizer.fractionalizeUniqueERC1155(fractionId, ipnftContract, uint256(1), agreementHash, 100_000);
        vm.stopPrank();
    }

    function testCannotFractionalizeWrongArgs() public {
        uint256 fractionId = helpInitializeFractions();

        vm.expectRevert("relay failed: only the owner may fractionalize on the collection");
        xDomainMessenger.sendMessage(
            address(fractionalizer),
            abi.encodeCall(
                Fractionalizer.fractionalizeUniqueERC1155,
                (fractionId, ipnftContract, uint256(2), originalOwner, originalOwner, agreementCid, 200_000)
            ),
            1_900_000
        );
    }
    */

    //todo move listing feats to another test file
    function helpCreateListing(uint256 price) public returns (uint256 listingId) {
        ipnft.setApprovalForAll(address(schmackoSwap), true);
        listingId = schmackoSwap.list(IERC1155Supply(address(ipnft)), 1, erc20, price, address(fractionalizer));

        schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
        return listingId;
    }

    // function helpInitializeFractions() internal returns (uint256 fractionId) {
    //     fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));

    //     fractionalizer.fractionalizeUniqueERC1155(fractionId, ipnftContract, uint256(1), agreementHash, 100_000);
    //     bytes memory message = abi.encodeCall(
    //         Fractionalizer.fractionalizeUniqueERC1155, (fractionId, ipnftContract, uint256(1), originalOwner, originalOwner, agreementCid, 100_000)
    //     );
    // }

    function testCreateListingAndSell() public {
        vm.startPrank(originalOwner);
        //ipnft.setApprovalForAll(address(fractionalizer), true);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        uint256 listingId = helpCreateListing(1_000_000 ether);
        vm.stopPrank();

        (,,,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState), uint256(ListingState.LISTED));

        //todo: prove we cannot start withdrawals at this point ;)
        vm.startPrank(ipnftBuyer);
        erc20.approve(address(schmackoSwap), 1_000_000 ether);
        schmackoSwap.fulfill(listingId);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(ipnftBuyer, 1), 1);
        assertEq(ipnft.balanceOf(originalOwner, 1), 0);
        assertEq(erc20.balanceOf(originalOwner), 0);
        assertEq(erc20.balanceOf(address(fractionalizer)), 1_000_000 ether);

        (,,,,,,, ListingState listingState2) = schmackoSwap.listings(listingId);
        assertEq(uint256(listingState2), uint256(ListingState.FULFILLED));
    }

    // function testClaimBuyoutShares() public {
    //     vm.startPrank(originalOwner);

    //     fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 25_000, "");
    //     fractionalizer.safeTransferFrom(originalOwner, bob, fractionId, 25_000, "");

    //     ipnft.setApprovalForAll(address(fractionalizer), true);
    //     uint256 fractionId = fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
    //     uint256 listingId = helpCreateListing(1_000_000 ether);
    //     vm.stopPrank();

    //     vm.startPrank(ipnftBuyer);
    //     erc20.approve(address(schmackoSwap), 1_000_000 ether);
    //     schmackoSwap.fulfill(listingId);
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     //someone must start the withdrawal phase first
    //     vm.expectRevert("claiming not available (yet)");
    //     fractionalizer.burnToWithdrawShare(fractionId);
    //     vm.stopPrank();

    //     // this is wanted: *anyone* (!) can call this. This is an oracle call.
    //     vm.startPrank(charlie);
    //     fractionalizer.afterSale(listingId, fractionId);
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     (IERC20 tokenContract, uint256 amount) = fractionalizer.claimableTokens(fractionId, alice);
    //     assertEq(amount, 250_000 ether);
    //     fractionalizer.burnToWithdrawShare(fractionId);
    //     vm.stopPrank();

    //     assertEq(erc20.balanceOf(alice), 250_000 ether);
    //     assertEq(erc20.balanceOf(address(fractionalizer)), 750_000 ether);
    //     assertEq(fractionalizer.totalSupply(fractionId), 75_000);

    //     assertEq(fractionalizer.balanceOf(alice, 1), 0);
    //     (, uint256 remainingAmount) = fractionalizer.claimableTokens(fractionId, alice);
    //     assertEq(remainingAmount, 0);

    //     assertEq(erc20.balanceOf(address(fractionalizer)), 0);
    //     (,,,, uint256 fulfilledListingId) = fractionalizer.fractionalized(fractionId);
    //     assertEq(listingId, fulfilledListingId);
    // }

    // function testStartClaimingPhase() public {
    //     vm.startPrank(originalOwner);
    //     ipnft.setApprovalForAll(address(fractionalizer), true);
    //     uint256 fractionId = fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
    //     uint256 listingId = helpCreateListing(1_000_000 ether);
    //     vm.stopPrank();

    //     vm.startPrank(ipnftBuyer);
    //     erc20.approve(address(schmackoSwap), 1_000_000 ether);
    //     schmackoSwap.fulfill(listingId);
    //     vm.stopPrank();
    //     assertEq(erc20.balanceOf(address(fractionalizer)), 1_000_000 ether);

    //     // this is wanted: *anyone* (!) can call this. This is an oracle call.
    //     vm.startPrank(charlie);
    //     fractionalizer.afterSale(fractionId, listingId);
    //     vm.stopPrank();

    //     assertEq(erc20.balanceOf(address(fractionalizer)), 0);
    //     (,,, uint256 fulfilledListingId) = fractionalizer.fractionalized(fractionId);
    //     assertEq(listingId, fulfilledListingId);
    // }

    // function testManuallyStartClaimingPhase() public {
    //     vm.startPrank(originalOwner);
    //     uint256 fractionId = fractionalizer.initializeFractionalization(ipnft, 1, originalOwner, agreementCid, 100_000);
    //     erc20.approve(address(fractionalizer), 1_000_000 ether);
    //     ipnft.safeTransferFrom(originalOwner, ipnftBuyer, 1, 1, "");
    //     vm.stopPrank();

    //     vm.startPrank(ipnftBuyer);
    //     erc20.transfer(originalOwner, 1_000_000 ether);
    //     vm.stopPrank();

    //     // this is wanted: *anyone* (!) can call this. This is an oracle call.
    //     vm.startPrank(originalOwner);
    //     fractionalizer.afterSale(fractionId, erc20, 1_000_000 ether);
    //     vm.stopPrank();

    //     assertEq(erc20.balanceOf(address(originalOwner)), 0);
    //     (,,,, uint256 fulfilledListingId) = fractionalizer.fractionalized(fractionId);
    //     assertFalse(fulfilledListingId == 0);
    // }

    // function testEscrowedFractionalization() public {
    //     vm.startPrank(originalOwner);
    //     ipnft.setApprovalForAll(address(fractionalizer), true);
    //     fractionalizer.initializeFractionalization(ipnft, 1, escrow, agreementCid, 100_000);
    //     vm.stopPrank();

    //     //here, the escrow contract initiates the listing
    //     vm.startPrank(escrow);
    //     uint256 listingId = helpCreateListing(1_000_000 ether);
    //     vm.stopPrank();

    //     (,,,,,,, ListingState listingState) = schmackoSwap.listings(listingId);
    //     assertEq(uint256(listingState), uint256(ListingState.LISTED));

    //     vm.startPrank(ipnftBuyer);
    //     erc20.approve(address(schmackoSwap), 1_000_000 ether);
    //     schmackoSwap.fulfill(listingId);
    //     vm.stopPrank();

    //     assertEq(ipnft.balanceOf(ipnftBuyer, 1), 1);
    //     assertEq(ipnft.balanceOf(escrow, 1), 0);
    //     assertEq(erc20.balanceOf(escrow), 0);
    //     assertEq(erc20.balanceOf(address(fractionalizer)), 1_000_000 ether);

    //     (,,,,,,, ListingState listingState2) = schmackoSwap.listings(listingId);
    //     assertEq(uint256(listingState2), uint256(ListingState.FULFILLED));
    // }

    // function testStartClaimingPhase() public {
    //     uint256 fractionId = helpInitializeFractions();

    //     vm.startPrank(ipnftBuyer);
    //     //this is handled by the L1 contract
    //     erc20.transfer(address(fractionalizer), 1_000_000 ether);
    //     vm.stopPrank();

    //     vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
    //     xDomainMessenger.setSender(originalOwner);

    //     fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
    //     vm.stopPrank();
    //     //todo: prove we cannot start withdrawals before this point

    //     vm.startPrank(originalOwner);
    //     vm.expectRevert("already in claiming phase");
    //     fractionalizer.increaseFractions(fractionId, 100_000);
    //     vm.stopPrank();
    // }

    // function testClaimBuyoutShares() public {
    //     uint256 fractionId = helpInitializeFractions();

    //     vm.startPrank(originalOwner);
    //     fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 25_000, "");
    //     fractionalizer.safeTransferFrom(originalOwner, bob, fractionId, 25_000, "");
    //     vm.stopPrank();

    //     vm.startPrank(ipnftBuyer);
    //     erc20.transfer(address(fractionalizer), 1_000_000 ether);
    //     vm.stopPrank();

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

    //     vm.startPrank(alice);
    //     //someone must start the claiming phase first
    //     vm.expectRevert("claiming not available (yet)");
    //     fractionalizer.burnToWithdrawShare(fractionId, abi.encodePacked(r, s, v));
    //     assertFalse(fractionalizer.signedTerms(fractionId, alice));
    //     vm.stopPrank();

    //     vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
    //     xDomainMessenger.setSender(originalOwner);
    //     fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     (, uint256 amount) = fractionalizer.claimableTokens(fractionId, alice);
    //     assertEq(amount, 250_000 ether);
    //     fractionalizer.burnToWithdrawShare(fractionId, abi.encodePacked(r, s, v));
    //     vm.stopPrank();

    //     assertEq(erc20.balanceOf(alice), 250_000 ether);
    //     assertEq(erc20.balanceOf(address(fractionalizer)), 750_000 ether);
    //     assertEq(fractionalizer.totalSupply(fractionId), 75_000);

    //     assertEq(fractionalizer.balanceOf(alice, 1), 0);
    //     (, uint256 remainingAmount) = fractionalizer.claimableTokens(fractionId, alice);
    //     assertEq(remainingAmount, 0);

    //     //a side effect of burning is that we mark the terms as accepted
    //     assertTrue(fractionalizer.signedTerms(fractionId, alice));

    //     //claims can be transferred to others and are redeemable by them
    //     (address charlie, uint256 charliePk) = makeAddrAndKey("charlie");

    //     vm.startPrank(bob);
    //     fractionalizer.safeTransferFrom(bob, charlie, fractionId, 20_000, "");
    //     vm.stopPrank();

    //     (, uint256 claimableByCharlie) = fractionalizer.claimableTokens(fractionId, charlie);
    //     assertEq(claimableByCharlie, 200_000 ether);

    //     (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

    //     vm.startPrank(charlie);
    //     fractionalizer.acceptTerms(fractionId, abi.encodePacked(r, s, v));
    //     fractionalizer.burnToWithdrawShare(fractionId);
    //     vm.stopPrank();

    //     assertEq(erc20.balanceOf(charlie), 200_000 ether);
    //     assertEq(erc20.balanceOf(address(fractionalizer)), 550_000 ether);
    // }

    // function testStartClaimingHighAmounts() public {
    //     uint256 fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));
    //     uint256 __wealth = 1_000_000_000_000_000_000_000 ether; //!!!

    //     xDomainMessenger.setSender(FakeL1DispatcherContract);
    //     bytes memory message = abi.encodeCall(
    //         Fractionalizer.fractionalizeUniqueERC1155, (fractionId, ipnftContract, uint256(1), originalOwner, alice, agreementCid, __wealth)
    //     );

    //     assertEq(fractionalizer.balanceOf(alice, fractionId), __wealth);

    //     myToken.mint(ipnftBuyer, __wealth);
    //     vm.startPrank(ipnftBuyer);
    //     erc20.transfer(address(fractionalizer), __wealth);
    //     vm.stopPrank();

    //     vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
    //     xDomainMessenger.setSender(FakeL1DispatcherContract);
    //     fractionalizer.afterSale(fractionId, address(erc20), __wealth);
    //     vm.stopPrank();

    //     vm.expectRevert( /*Arithmetic over/underflow*/ );
    //     (, uint256 amount) = fractionalizer.claimableTokens(fractionId, alice);
    //     //assertEq(amount, __wealth);
    // }

    // function testCollectionBalanceMustBeOne() public {
    //     //cant fractionalize 1155 tokens with a supply > 1
    // }

    // function testMetaTxAreAcceptedForTransfers() public {
    //     //call the transfer methods with signed meta transactions
    // }

    // function testProveSigAndAcceptTerms() public {
    //     uint256 fractionId = helpInitializeFractions();

    //     string memory terms = fractionalizer.specificTermsV1(fractionId);
    //     //console.log(terms);
    //     bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(terms));

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, termsHash);
    //     bytes memory xsignature = abi.encodePacked(r, s, v);
    //     assertTrue(fractionalizer.isValidSignature(fractionId, alice, xsignature));

    //     assertFalse(fractionalizer.signedTerms(fractionId, alice));
    //     vm.startPrank(alice);
    //     fractionalizer.acceptTerms(fractionId, xsignature);
    //     vm.stopPrank();
    //     assertTrue(fractionalizer.signedTerms(fractionId, alice));
    // }

    // function testThatContractSignaturesAreAccepted() public {
    //     //craft an eip1271 signature
    // }

    // function testGnosisSafeCanInteractWithFractions() public {
    //     vm.startPrank(deployer);
    //     GnosisSafeProxyFactory fac = new GnosisSafeProxyFactory();
    //     vm.stopPrank();

    //     vm.startPrank(alice);

    //     address[] memory owners = new address[](1);
    //     owners[0] = alice;
    //     GnosisSafeL2 wallet = MakeGnosisWallet.makeGnosisWallet(fac, owners);
    //     vm.stopPrank();

    //     uint256 fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));

    //     xDomainMessenger.setSender(FakeL1DispatcherContract);
    //     bytes memory message = abi.encodeCall(
    //         fractionalizer.fractionalizeUniqueERC1155, (fractionId, ipnftContract, uint256(1), originalOwner, address(wallet), agreementCid, 100_000)
    //     );

    //     xDomainMessenger.sendMessage(address(fractionalizer), message, 2_900_000);
    //     assertEq(fractionalizer.balanceOf(address(wallet), fractionId), 100_000);

    //     //test the SAFE can send fractions to another account
    //     bytes memory transferCall = abi.encodeCall(fractionalizer.safeTransferFrom, (address(wallet), bob, fractionId, 10_000, bytes("")));
    //     bytes32 encodedTxDataHash = wallet.getTransactionHash(
    //         address(fractionalizer), 0, transferCall, Enum.Operation.Call, 80_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), 0
    //     );

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, encodedTxDataHash);
    //     bytes memory xsignatures = abi.encodePacked(r, s, v);

    //     vm.startPrank(alice);
    //     wallet.execTransaction(
    //         address(fractionalizer), 0, transferCall, Enum.Operation.Call, 80_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), xsignatures
    //     );
    //     vm.stopPrank();

    //     assertEq(fractionalizer.balanceOf(bob, fractionId), 10_000);

    //     //signing terms with a multisig

    //     assertFalse(fractionalizer.signedTerms(fractionId, address(wallet)));
    //     //new SignMessageLib();

    //     // string memory terms = fractionalizer.specificTermsV1(fractionId);
    //     // //console.log(terms);
    //     // bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(terms));

    //     // (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, termsHash);
    //     // bytes memory xsignature = abi.encodePacked(r, s, v);
    //     // assertTrue(fractionalizer.isValidSignature(fractionId, alice, xsignature));

    //     // vm.startPrank(alice);
    //     // fractionalizer.acceptTerms(fractionId, xsignature);
    //     // vm.stopPrank();
    //     // assertTrue(fractionalizer.signedTerms(fractionId, alice));

    //     //lets start aftersales phase
    //     // vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
    //     // xDomainMessenger.setSender(FakeL1DispatcherContract);
    //     // fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
    //     // vm.stopPrank();
    // }
}

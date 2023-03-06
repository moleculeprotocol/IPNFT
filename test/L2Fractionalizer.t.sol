// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { MockCrossDomainMessenger } from "./helpers/MockCrossDomainMessenger.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Fractionalizer } from "../src/Fractionalizer.sol";
import { MyToken } from "../src/MyToken.sol";

contract L2FractionalizerTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    bytes32 agreementHash = keccak256(bytes("the binary content of the fraction holder agreeemnt"));

    address PREDEPLOYED_XDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");
    address ipnftContract = makeAddr("ipnftv21");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");

    Fractionalizer internal fractionalizer;
    IERC20 internal erc20;
    MockCrossDomainMessenger internal xDomainMessenger;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");

        vm.startPrank(deployer);

        MyToken myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        xDomainMessenger = new MockCrossDomainMessenger();
        vm.etch(PREDEPLOYED_XDOMAIN_MESSENGER, address(xDomainMessenger).code);
        xDomainMessenger = MockCrossDomainMessenger(PREDEPLOYED_XDOMAIN_MESSENGER);

        fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(
                        new Fractionalizer()
                    ), ""
                )
            )
        );
        fractionalizer.initialize();

        //fractionalizer.setFeeReceiver(protocolOwner);

        vm.stopPrank();
    }

    function helpInitializeFractions() internal returns (uint256 fractionId) {
        fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));

        vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        xDomainMessenger.setSender(originalOwner);
        fractionalizer.fractionalizeUniqueERC1155(fractionId, ipnftContract, uint256(1), agreementHash, 100_000);
        vm.stopPrank();
    }

    function testIssueFractions() public {
        uint256 fractionId = helpInitializeFractions();

        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 100_000);

        (,, uint256 totalIssued,,,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 100_000);

        vm.startPrank(originalOwner);
        fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 10_000, "");
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 10_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 90_000);
        assertEq(fractionalizer.totalSupply(fractionId), 100_000);
    }

    function testIncreaseFractions() public {
        uint256 fractionId = helpInitializeFractions();

        vm.startPrank(originalOwner);
        fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 25_000, "");
        fractionalizer.safeTransferFrom(originalOwner, bob, fractionId, 25_000, "");

        fractionalizer.increaseFractions(fractionId, 100_000);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(bob, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 150_000);
        assertEq(fractionalizer.totalSupply(fractionId), 200_000);

        (,, uint256 totalIssued,,,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 200_000);
    }

    function testCanBeFractionalizedOnlyOnce() public {
        uint256 fractionId = helpInitializeFractions();

        vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        xDomainMessenger.setSender(originalOwner);

        vm.expectRevert("token is already fractionalized");
        fractionalizer.fractionalizeUniqueERC1155(fractionId, ipnftContract, uint256(1), agreementHash, 100_000);
        vm.stopPrank();
    }

    // function helpCreateListing(uint256 price) public returns (uint256 listingId) {
    //     ipnft.setApprovalForAll(address(schmackoSwap), true);
    //     listingId = schmackoSwap.listFor(ipnft, 1, erc20, price, address(fractionalizer));

    //     schmackoSwap.changeBuyerAllowance(listingId, ipnftBuyer, true);
    //     return listingId;
    // }

    function testStartClaimingPhase() public {
        uint256 fractionId = helpInitializeFractions();

        vm.startPrank(ipnftBuyer);
        //this is handled by the L1 contract
        erc20.transfer(address(fractionalizer), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        xDomainMessenger.setSender(originalOwner);

        //todo: this shall be callable by anyone but it must be ensured on L2
        //that the deal really happened.
        //todo: prove we cannot start withdrawals before this point
        fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        vm.expectRevert("already in claiming phase");
        fractionalizer.increaseFractions(fractionId, 100_000);
        vm.stopPrank();
    }

    function testClaimBuyoutShares() public {
        uint256 fractionId = helpInitializeFractions();

        vm.startPrank(originalOwner);
        fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 25_000, "");
        fractionalizer.safeTransferFrom(originalOwner, bob, fractionId, 25_000, "");
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        erc20.transfer(address(fractionalizer), 1_000_000 ether);
        vm.stopPrank();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, keccak256(bytes(fractionalizer.specificTermsV1(fractionId))));

        vm.startPrank(alice);
        //someone must start the claiming phase first
        vm.expectRevert("claiming not available (yet)");
        fractionalizer.burnToWithdrawShare(fractionId, v, r, s);
        assertFalse(fractionalizer.signedTerms(fractionId, alice));
        vm.stopPrank();

        vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        xDomainMessenger.setSender(originalOwner);
        fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        (, uint256 amount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(amount, 250_000 ether);
        fractionalizer.burnToWithdrawShare(fractionId, v, r, s);
        vm.stopPrank();

        assertEq(erc20.balanceOf(alice), 250_000 ether);
        assertEq(erc20.balanceOf(address(fractionalizer)), 750_000 ether);
        assertEq(fractionalizer.totalSupply(fractionId), 75_000);

        assertEq(fractionalizer.balanceOf(alice, 1), 0);
        (, uint256 remainingAmount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(remainingAmount, 0);

        //a side effect of burning is that we mark the terms as accepted
        assertTrue(fractionalizer.signedTerms(fractionId, alice));

        //claims can be transferred to others and are redeemable by them
        (address charlie, uint256 charliePk) = makeAddrAndKey("charlie");

        vm.startPrank(bob);
        fractionalizer.safeTransferFrom(bob, charlie, fractionId, 20_000, "");
        vm.stopPrank();

        (, uint256 claimableByCharlie) = fractionalizer.claimableTokens(fractionId, charlie);
        assertEq(claimableByCharlie, 200_000 ether);

        (v, r, s) = vm.sign(charliePk, keccak256(bytes(fractionalizer.specificTermsV1(fractionId))));

        vm.startPrank(charlie);
        fractionalizer.acceptTerms(fractionId, v, r, s);
        fractionalizer.burnToWithdrawShare(fractionId);
        vm.stopPrank();

        assertEq(erc20.balanceOf(charlie), 200_000 ether);
        assertEq(erc20.balanceOf(address(fractionalizer)), 550_000 ether);
    }

    // function testCollectionBalanceMustBeOne() public {
    //     //cant fractionalize 1155 tokens with a supply > 1
    // }

    function testProveSigAndAcceptTerms() public {
        uint256 fractionId = helpInitializeFractions();

        string memory terms = fractionalizer.specificTermsV1(fractionId);
        console.log(terms);
        bytes32 termsHash = keccak256(bytes(terms));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, termsHash);

        address signer = fractionalizer.signedBy(fractionId, v, r, s);
        assertEq(signer, alice);

        assertFalse(fractionalizer.signedTerms(fractionId, alice));
        vm.startPrank(alice);
        fractionalizer.acceptTerms(fractionId, v, r, s);
        vm.stopPrank();
        assertTrue(fractionalizer.signedTerms(fractionId, alice));
    }
}

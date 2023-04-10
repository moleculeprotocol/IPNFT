// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { GnosisSafeL2 } from "safe-global/safe-contracts/GnosisSafeL2.sol";
import { GnosisSafeProxyFactory } from "safe-global/safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";

import { MockCrossDomainMessenger } from "./helpers/MockCrossDomainMessenger.sol";
import "./helpers/MakeGnosisWallet.sol";

import { Fractionalizer, ToZeroAddress, InsufficientBalance, TermsNotAccepted, InvalidSignature } from "../src/Fractionalizer.sol";
import { MyToken } from "../src/MyToken.sol";

contract L2FractionalizerTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";

    //stripped cidv1 pfx from bafkreihjtgxfjfz6kguaw5bhnnua766dqkygrpaemzazhz3aufvc6tmate:
    bytes32 agreementHash = 0xe999ae54973e51a80b74276b680ffbc382b068bc04664193e760a16a2f4d8099;

    address PREDEPLOYED_XDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");
    address ipnftContract = makeAddr("ipnftv21");
    address FakeL1DispatcherContract = makeAddr("L1Dispatcher");

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
                        new Fractionalizer(address(0))
                    ), ""
                )
            )
        );
        fractionalizer.initialize();
        fractionalizer.setFractionalizerDispatcherL1(FakeL1DispatcherContract);
        //fractionalizer.setFeeReceiver(protocolOwner);

        vm.stopPrank();
    }

    function helpInitializeFractions() internal returns (uint256 fractionId) {
        fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));

        xDomainMessenger.setSender(FakeL1DispatcherContract);
        bytes memory message = abi.encodeCall(
            Fractionalizer.fractionalizeUniqueERC1155, (fractionId, ipnftContract, uint256(1), originalOwner, originalOwner, agreementHash, 100_000)
        );

        xDomainMessenger.sendMessage(address(fractionalizer), message, 1_900_000);
    }

    function testCannotSetInfraToZero() public {
        vm.startPrank(deployer);
        vm.expectRevert(ToZeroAddress.selector);
        fractionalizer.setFractionalizerDispatcherL1(address(0));

        vm.expectRevert(ToZeroAddress.selector);
        fractionalizer.setFeeReceiver(address(0));
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

        vm.startPrank(deployer);
        vm.expectRevert("only the original owner can update the distribution scheme");
        fractionalizer.increaseFractions(fractionId, 100_000);
        vm.stopPrank();

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

        vm.expectRevert("relay failed: token is already fractionalized");
        xDomainMessenger.sendMessage(
            address(fractionalizer),
            abi.encodeCall(
                Fractionalizer.fractionalizeUniqueERC1155,
                (fractionId, ipnftContract, uint256(1), originalOwner, originalOwner, agreementHash, 200_000)
            ),
            1_900_000
        );
    }

    function testCannotFractionalizeWrongArgs() public {
        uint256 fractionId = helpInitializeFractions();

        vm.expectRevert("relay failed: only the owner may fractionalize on the collection");
        xDomainMessenger.sendMessage(
            address(fractionalizer),
            abi.encodeCall(
                Fractionalizer.fractionalizeUniqueERC1155,
                (fractionId, ipnftContract, uint256(2), originalOwner, originalOwner, agreementHash, 200_000)
            ),
            1_900_000
        );
    }

    function testStartClaimingPhase() public {
        uint256 fractionId = helpInitializeFractions();

        vm.startPrank(ipnftBuyer);
        //this is handled by the L1 contract
        erc20.transfer(address(fractionalizer), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        xDomainMessenger.setSender(FakeL1DispatcherContract);

        fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
        vm.stopPrank();
        //todo: prove we cannot start withdrawals before this point

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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

        vm.startPrank(alice);
        //someone must start the claiming phase first
        vm.expectRevert("claiming not available (yet)");
        fractionalizer.burnToWithdrawShare(fractionId, abi.encodePacked(r, s, v));
        assertFalse(fractionalizer.signedTerms(fractionId, alice));
        vm.stopPrank();

        vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        xDomainMessenger.setSender(FakeL1DispatcherContract);
        fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
        vm.stopPrank();

        vm.startPrank(ipnftBuyer);
        vm.expectRevert(InsufficientBalance.selector);
        fractionalizer.burnToWithdrawShare(fractionId);
        vm.stopPrank();

        vm.startPrank(alice);
        (, uint256 amount) = fractionalizer.claimableTokens(fractionId, alice);
        assertEq(amount, 250_000 ether);

        vm.expectRevert(TermsNotAccepted.selector);
        fractionalizer.burnToWithdrawShare(fractionId);

        fractionalizer.burnToWithdrawShare(fractionId, abi.encodePacked(r, s, v));
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

        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(fractionalizer.specificTermsV1(fractionId))));

        vm.startPrank(charlie);
        fractionalizer.acceptTerms(fractionId, abi.encodePacked(r, s, v));
        fractionalizer.burnToWithdrawShare(fractionId);
        vm.stopPrank();

        assertEq(erc20.balanceOf(charlie), 200_000 ether);
        assertEq(erc20.balanceOf(address(fractionalizer)), 550_000 ether);
    }

    // function testCollectionBalanceMustBeOne() public {
    //     //cant fractionalize 1155 tokens with a supply > 1
    // }

    // function testMetaTxAreAcceptedForTransfers() public {
    //     //call the transfer methods with signed meta transactions
    // }

    function testProveSigAndAcceptTerms() public {
        uint256 fractionId = helpInitializeFractions();

        string memory terms = fractionalizer.specificTermsV1(fractionId);
        //console.log(terms);
        bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(terms));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, termsHash);
        bytes memory xsignature = abi.encodePacked(r, s, v);
        assertTrue(fractionalizer.isValidSignature(fractionId, alice, xsignature));

        assertFalse(fractionalizer.signedTerms(fractionId, alice));
        vm.startPrank(alice);
        vm.expectRevert(InvalidSignature.selector);
        fractionalizer.acceptTerms(fractionId, bytes(""));

        fractionalizer.acceptTerms(fractionId, xsignature);
        vm.stopPrank();
        assertTrue(fractionalizer.signedTerms(fractionId, alice));
    }

    // function testThatContractSignaturesAreAccepted() public {
    //     //craft an eip1271 signature
    // }

    function testGnosisSafeCanInteractWithFractions() public {
        vm.startPrank(deployer);
        GnosisSafeProxyFactory fac = new GnosisSafeProxyFactory();
        vm.stopPrank();

        vm.startPrank(alice);

        address[] memory owners = new address[](1);
        owners[0] = alice;
        GnosisSafeL2 wallet = MakeGnosisWallet.makeGnosisWallet(fac, owners);
        vm.stopPrank();

        uint256 fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));

        xDomainMessenger.setSender(FakeL1DispatcherContract);
        bytes memory message = abi.encodeCall(
            fractionalizer.fractionalizeUniqueERC1155, (fractionId, ipnftContract, uint256(1), originalOwner, address(wallet), agreementHash, 100_000)
        );

        xDomainMessenger.sendMessage(address(fractionalizer), message, 2_900_000);
        assertEq(fractionalizer.balanceOf(address(wallet), fractionId), 100_000);

        //test the SAFE can send fractions to another account
        bytes memory transferCall = abi.encodeCall(fractionalizer.safeTransferFrom, (address(wallet), bob, fractionId, 10_000, bytes("")));
        bytes32 encodedTxDataHash = wallet.getTransactionHash(
            address(fractionalizer), 0, transferCall, Enum.Operation.Call, 80_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), 0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, encodedTxDataHash);
        bytes memory xsignatures = abi.encodePacked(r, s, v);

        vm.startPrank(alice);
        wallet.execTransaction(
            address(fractionalizer), 0, transferCall, Enum.Operation.Call, 80_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), xsignatures
        );
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(bob, fractionId), 10_000);

        //signing terms with a multisig

        assertFalse(fractionalizer.signedTerms(fractionId, address(wallet)));
        //new SignMessageLib();

        // string memory terms = fractionalizer.specificTermsV1(fractionId);
        // //console.log(terms);
        // bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(terms));

        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, termsHash);
        // bytes memory xsignature = abi.encodePacked(r, s, v);
        // assertTrue(fractionalizer.isValidSignature(fractionId, alice, xsignature));

        // vm.startPrank(alice);
        // fractionalizer.acceptTerms(fractionId, xsignature);
        // vm.stopPrank();
        // assertTrue(fractionalizer.signedTerms(fractionId, alice));

        //lets start aftersales phase
        // vm.startPrank(PREDEPLOYED_XDOMAIN_MESSENGER);
        // xDomainMessenger.setSender(FakeL1DispatcherContract);
        // fractionalizer.afterSale(fractionId, address(erc20), 1_000_000 ether);
        // vm.stopPrank();
    }
}

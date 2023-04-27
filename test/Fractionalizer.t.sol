// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { GnosisSafeL2 } from "safe-global/safe-contracts/GnosisSafeL2.sol";
import { GnosisSafeProxyFactory } from "safe-global/safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";
import "./helpers/MakeGnosisWallet.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";

import { Fractionalizer, Fractionalized } from "../src/Fractionalizer.sol";
import { ToZeroAddress, BadSupply, MustOwnIpnft, NoSymbol, AlreadyFractionalized, InvalidSignature } from "../src/Fractionalizer.sol";

import { FractionalizedTokenUpgradeable as FractionalizedToken } from "../src/FractionalizedToken.sol";
import { FractionalizerNext, FractionalizedTokenUpgradeableNext } from "../src/helpers/upgrades/FractionalizerNext.sol";

import { IERC1155Supply } from "../src/IERC1155Supply.sol";
import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";
import { MyToken } from "../src/MyToken.sol";

contract FractionalizerTest is Test {
    using SafeERC20Upgradeable for FractionalizedToken;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address escrow = makeAddr("escrow");

    IPNFT internal ipnft;
    Fractionalizer internal fractionalizer;
    SchmackoSwap internal schmackoSwap;
    Mintpass internal mintpass;

    IERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        MyToken myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        mintpass.batchMint(originalOwner, 1);

        fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(
                        new Fractionalizer()
                    ), 
                    ""
                )
            )
        );
        fractionalizer.initialize(ipnft, schmackoSwap);
        fractionalizer.setFeeReceiver(protocolOwner);
        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, 1, ipfsUri, DEFAULT_SYMBOL);
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
        assertEq(tokenContract.symbol(), "MOL-0001");

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

        vm.startPrank(bob);
        vm.expectRevert(MustOwnIpnft.selector);
        fractionalizer.increaseFractions(fractionId, 12345);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(bob, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 150_000);
        assertEq(fractionalizer.totalSupply(fractionId), 200_000);

        (, totalIssued,,,,,,) = fractionalizer.fractionalized(fractionId);

        (, totalIssued,,,,,,) = fractionalizer.fractionalized(fractionId);
        assertEq(totalIssued, 200_000);
    }

    function testCanBeFractionalizedOnlyOnce() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);

        vm.expectRevert(AlreadyFractionalized.selector);
        fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();
    }

    function testCannotFractionalizeIfNotOwner() public {
        vm.startPrank(alice);

        vm.expectRevert(MustOwnIpnft.selector);
        fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();
    }

    function testProveSigAndAcceptTerms() public {
        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);

        string memory terms = fractionalizer.specificTermsV1(fractionId);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));

        bytes memory xsignature = abi.encodePacked(r, s, v);
        assertTrue(fractionalizer.isValidSignature(fractionId, alice, xsignature));

        vm.expectRevert(InvalidSignature.selector);
        fractionalizer.acceptTerms(fractionId, xsignature);
        vm.stopPrank();

        vm.startPrank(alice);
        fractionalizer.acceptTerms(fractionId, xsignature);
        vm.stopPrank();
    }

    function testGnosisSafeCanInteractWithFractions() public {
        vm.startPrank(deployer);
        GnosisSafeProxyFactory fac = new GnosisSafeProxyFactory();
        vm.stopPrank();

        vm.startPrank(alice);
        address[] memory owners = new address[](1);
        owners[0] = alice;
        GnosisSafeL2 wallet = MakeGnosisWallet.makeGnosisWallet(fac, owners);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        (,,,, FractionalizedToken tokenContract,,,) = fractionalizer.fractionalized(fractionId);
        tokenContract.safeTransfer(address(wallet), 100_000);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(address(wallet), fractionId), 100_000);

        //test the SAFE can send fractions to another account
        bytes memory transferCall = abi.encodeCall(tokenContract.transfer, (bob, 10_000));
        bytes32 encodedTxDataHash = wallet.getTransactionHash(
            address(tokenContract), 0, transferCall, Enum.Operation.Call, 80_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), 0
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, encodedTxDataHash);
        bytes memory xsignatures = abi.encodePacked(r, s, v);

        vm.startPrank(alice);
        wallet.execTransaction(
            address(tokenContract), 0, transferCall, Enum.Operation.Call, 80_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), xsignatures
        );
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(bob, fractionId), 10_000);
    }

    //todo: good luck.
    function testThatContractSignaturesAreAccepted() public {
        // //signing terms with a multisig

        // assertFalse(fractionalizer.signedTerms(fractionId, address(wallet)));
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

    function testCanUpgradeErc20TokenImplementation() public {
        vm.startPrank(deployer);
        mintpass.batchMint(originalOwner, 1);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        uint256 fractionId = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();

        vm.startPrank(deployer);
        FractionalizerNext fracNext = new FractionalizerNext();
        fractionalizer.upgradeTo(address(fracNext));
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 100_000);
        (,,,, FractionalizedToken tokenContractOld,,,) = fractionalizer.fractionalized(fractionId);
        assertEq(tokenContractOld.balanceOf(originalOwner), 100_000);

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, 2, ipfsUri, DEFAULT_SYMBOL);
        fractionId = fractionalizer.fractionalizeIpnft(2, 70_000, agreementCid);
        vm.stopPrank();

        (,,,, FractionalizedToken tokenContractNew,,,) = fractionalizer.fractionalized(fractionId);
        FractionalizedTokenUpgradeableNext newTokenImpl = FractionalizedTokenUpgradeableNext(address(tokenContractNew));

        assertEq(fractionalizer.balanceOf(originalOwner, fractionId), 70_000);
        assertEq(tokenContractNew.balanceOf(originalOwner), 70_000);

        newTokenImpl.setAStateVar(42);
        assertEq(newTokenImpl.aNewStateVar(), 42);

        FractionalizedTokenUpgradeableNext oldTokenImplWrapped = FractionalizedTokenUpgradeableNext(address(tokenContractOld));
        vm.expectRevert();
        oldTokenImplWrapped.setAStateVar(42);
    }
}

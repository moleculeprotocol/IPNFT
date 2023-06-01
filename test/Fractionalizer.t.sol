// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { Safe } from "safe-global/safe-contracts/Safe.sol";
import { SafeProxyFactory } from "safe-global/safe-contracts/proxies/SafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";
import "./helpers/MakeGnosisWallet.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { MustOwnIpnft, NoSymbol, AlreadyFractionalized } from "../src/Fractionalizer.sol";

import { FractionalizedToken, OnlyIssuerOrOwner, TokenCapped } from "../src/FractionalizedToken.sol";
import { FractionalizerNext, FractionalizedTokenNext } from "../src/helpers/test-upgrades/FractionalizerNext.sol";

import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";

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
    uint256 bobPk;
    address charlie = makeAddr("charlie");
    address escrow = makeAddr("escrow");

    IPNFT internal ipnft;
    Fractionalizer internal fractionalizer;
    SchmackoSwap internal schmackoSwap;
    Mintpass internal mintpass;

    FakeERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        vm.startPrank(deployer);

        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        erc20 = new FakeERC20("Fake ERC20", "FERC");
        erc20.mint(ipnftBuyer, 1_000_000 ether);

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
        fractionalizer.initialize(ipnft);
        fractionalizer.setFeeReceiver(protocolOwner);
        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, 1, ipfsUri, DEFAULT_SYMBOL);
        vm.stopPrank();
    }

    function testCannotSetInfraToZero() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        fractionalizer.setReceiverPercentage(10);
        vm.stopPrank();
    }

    function testUrl() public {
        vm.startPrank(originalOwner);
        FractionalizedToken tokenContract = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        string memory uri = tokenContract.uri();
        assertGt(bytes(uri).length, 200);
        vm.stopPrank();
    }

    function testIssueFractions() public {
        vm.startPrank(originalOwner);
        //ipnft.setApprovalForAll(address(fractionalizer), true);
        FractionalizedToken tokenContract = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(originalOwner), 100_000);
        //the original nft *stays* at the owner
        assertEq(ipnft.ownerOf(1), originalOwner);

        assertEq(tokenContract.totalIssued(), 100_000);
        assertEq(tokenContract.symbol(), "MOL-0001-MOL");

        vm.startPrank(originalOwner);
        tokenContract.transfer(alice, 10_000);
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(alice), 10_000);
        assertEq(tokenContract.balanceOf(originalOwner), 90_000);
        assertEq(tokenContract.totalSupply(), 100_000);
    }

    function testIncreaseFractions() public {
        vm.startPrank(originalOwner);
        FractionalizedToken tokenContract = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);

        tokenContract.transfer(alice, 25_000);
        tokenContract.transfer(bob, 25_000);

        tokenContract.issue(originalOwner, 100_000);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(OnlyIssuerOrOwner.selector);
        tokenContract.issue(bob, 12345);
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(alice), 25_000);
        assertEq(tokenContract.balanceOf(bob), 25_000);
        assertEq(tokenContract.balanceOf(originalOwner), 150_000);
        assertEq(tokenContract.totalSupply(), 200_000);
        assertEq(tokenContract.totalIssued(), 200_000);

        vm.startPrank(bob);
        vm.expectRevert(OnlyIssuerOrOwner.selector);
        tokenContract.cap();
        vm.stopPrank();

        vm.startPrank(originalOwner);
        tokenContract.cap();
        vm.expectRevert(TokenCapped.selector);
        tokenContract.issue(bob, 12345);
        vm.stopPrank();
    }

    function testCanBeFractionalizedOnlyOnce() public {
        vm.startPrank(originalOwner);
        fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);

        vm.expectRevert(AlreadyFractionalized.selector);
        fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();
    }

    function testCannotFractionalizeIfNotOwner() public {
        vm.startPrank(alice);

        vm.expectRevert(MustOwnIpnft.selector);
        fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();
    }

    function testGnosisSafeCanInteractWithFractions() public {
        vm.startPrank(deployer);
        SafeProxyFactory fac = new SafeProxyFactory();
        vm.stopPrank();

        vm.startPrank(alice);
        address[] memory owners = new address[](1);
        owners[0] = alice;
        Safe wallet = MakeGnosisWallet.makeGnosisWallet(fac, owners);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        FractionalizedToken tokenContract = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        tokenContract.safeTransfer(address(wallet), 100_000);
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(address(wallet)), 100_000);

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

        assertEq(tokenContract.balanceOf(bob), 10_000);
    }

    function testCanUpgradeErc20TokenImplementation() public {
        vm.startPrank(deployer);
        mintpass.batchMint(originalOwner, 1);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        FractionalizedToken tokenContractOld = fractionalizer.fractionalizeIpnft(1, 100_000, agreementCid);
        vm.stopPrank();

        vm.startPrank(deployer);
        FractionalizerNext fracNext = new FractionalizerNext();
        fractionalizer.upgradeTo(address(fracNext));
        vm.stopPrank();

        assertEq(tokenContractOld.balanceOf(originalOwner), 100_000);

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, 2, ipfsUri, DEFAULT_SYMBOL);
        FractionalizedToken tokenContractNew = fractionalizer.fractionalizeIpnft(2, 70_000, agreementCid);
        vm.stopPrank();

        assertEq(tokenContractNew.balanceOf(originalOwner), 70_000);

        FractionalizedTokenNext newTokenImpl = FractionalizedTokenNext(address(tokenContractNew));

        newTokenImpl.setAStateVar(42);
        assertEq(newTokenImpl.aNewStateVar(), 42);

        FractionalizedTokenNext oldTokenImplWrapped = FractionalizedTokenNext(address(tokenContractOld));
        vm.expectRevert();
        oldTokenImplWrapped.setAStateVar(42);
    }
}

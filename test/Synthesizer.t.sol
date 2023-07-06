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
import { AcceptAllMintAuthorizer, IAuthorizeMints } from "../src/IAuthorizeMints.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { Synthesizer } from "../src/Synthesizer.sol";
import { MustOwnIpnft, AlreadySynthesized } from "../src/Synthesizer.sol";

import { Molecules, OnlyIssuerOrOwner, TokenCapped } from "../src/Molecules.sol";
import { SynthesizerNext, MoleculesNext } from "../src/helpers/test-upgrades/SynthesizerNext.sol";
import { IPermissioner, BlindPermissioner } from "../src/Permissioner.sol";

import { SchmackoSwap, ListingState } from "../src/SchmackoSwap.sol";

contract SynthesizerTest is Test {
    using SafeERC20Upgradeable for Molecules;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "MOL-0001";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are molecules holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    uint256 bobPk;
    address charlie = makeAddr("charlie");
    address escrow = makeAddr("escrow");
    bytes authorization = "";
    IPNFT internal ipnft;
    Synthesizer internal synthesizer;
    SchmackoSwap internal schmackoSwap;
    IAuthorizeMints internal authorizer;
    IPermissioner internal blindPermissioner;

    FakeERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        vm.startPrank(deployer);

        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), '')));
        ipnft.initialize();

        schmackoSwap = new SchmackoSwap();
        erc20 = new FakeERC20('Fake ERC20', 'FERC');
        erc20.mint(ipnftBuyer, 1_000_000 ether);

        authorizer = new AcceptAllMintAuthorizer();
        ipnft.setAuthorizer(address(authorizer));
        blindPermissioner = new BlindPermissioner();

        synthesizer = Synthesizer(address(new ERC1967Proxy(address(new Synthesizer()), '')));
        synthesizer.initialize(ipnft, blindPermissioner);

        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, authorization);
        vm.stopPrank();
    }

    function testUrl() public {
        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        string memory uri = tokenContract.uri();
        assertGt(bytes(uri).length, 200);
        vm.stopPrank();
    }

    function testIssueMolecules() public {
        vm.startPrank(originalOwner);
        //ipnft.setApprovalForAll(address(synthesizer), true);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(originalOwner), 100_000);
        //the original nft *stays* at the owner
        assertEq(ipnft.ownerOf(1), originalOwner);

        assertEq(tokenContract.totalIssued(), 100_000);
        assertEq(tokenContract.symbol(), "MOLE");

        vm.startPrank(originalOwner);
        tokenContract.transfer(alice, 10_000);
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(alice), 10_000);
        assertEq(tokenContract.balanceOf(originalOwner), 90_000);
        assertEq(tokenContract.totalSupply(), 100_000);
    }

    function testIncreaseMolecules() public {
        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");

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

    function testCanBeSynthesizedOnlyOnce() public {
        vm.startPrank(originalOwner);
        synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");

        vm.expectRevert(AlreadySynthesized.selector);
        synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        vm.stopPrank();
    }

    function testCannotSynthesizeIfNotOwner() public {
        vm.startPrank(alice);

        vm.expectRevert(MustOwnIpnft.selector);
        synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        vm.stopPrank();
    }

    function testGnosisSafeCanInteractWithMolecules() public {
        vm.startPrank(deployer);
        SafeProxyFactory fac = new SafeProxyFactory();
        vm.stopPrank();

        vm.startPrank(alice);
        address[] memory owners = new address[](1);
        owners[0] = alice;
        Safe wallet = MakeGnosisWallet.makeGnosisWallet(fac, owners);
        vm.stopPrank();

        vm.startPrank(originalOwner);
        Molecules tokenContract = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        tokenContract.safeTransfer(address(wallet), 100_000);
        vm.stopPrank();

        assertEq(tokenContract.balanceOf(address(wallet)), 100_000);

        //test the SAFE can send molecules to another account
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
        vm.stopPrank();

        vm.startPrank(originalOwner);
        Molecules tokenContractOld = synthesizer.synthesizeIpnft(1, 100_000, "MOLE", agreementCid, "");
        vm.stopPrank();

        vm.startPrank(deployer);
        SynthesizerNext synthNext = new SynthesizerNext();
        synthesizer.upgradeTo(address(synthNext));
        SynthesizerNext synth2 = SynthesizerNext(address(synthesizer));

        IPermissioner _permissioner = new BlindPermissioner();
        synth2.reinit(_permissioner);
        vm.stopPrank();

        assertEq(tokenContractOld.balanceOf(originalOwner), 100_000);

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, authorization);
        Molecules tokenContractNew = synth2.synthesizeIpnft(2, 70_000, agreementCid, "");
        vm.stopPrank();

        assertEq(tokenContractNew.balanceOf(originalOwner), 70_000);

        MoleculesNext newTokenImpl = MoleculesNext(address(tokenContractNew));

        newTokenImpl.setAStateVar(42);
        assertEq(newTokenImpl.aNewStateVar(), 42);

        MoleculesNext oldTokenImplWrapped = MoleculesNext(address(tokenContractOld));
        vm.expectRevert();
        oldTokenImplWrapped.setAStateVar(42);
    }
}

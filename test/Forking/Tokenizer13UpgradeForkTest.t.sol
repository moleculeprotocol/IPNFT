// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IPNFT } from "../../src/IPNFT.sol";

import { MustControlIpnft, AlreadyTokenized, Tokenizer } from "../../src/Tokenizer.sol";
import { Tokenizer12 } from "../../src/helpers/test-upgrades/Tokenizer12.sol";
import { IPToken12, OnlyIssuerOrOwner } from "../../src/helpers/test-upgrades/IPToken12.sol";
import { IPToken, TokenCapped, Metadata } from "../../src/IPToken.sol";
import { IPermissioner, BlindPermissioner } from "../../src/Permissioner.sol";

contract Tokenizer13UpgradeForkTest is Test {
    using SafeERC20Upgradeable for IPToken;

    uint256 mainnetFork;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "IPT-0001";

    address mainnetDeployer = 0x34021576F01275A429163a56908Bd02b43e2B7e1;
    address mainnetOwner = 0xCfA0F84660fB33bFd07C369E5491Ab02C449f71B;
    address mainnetTokenizer = 0x58EB89C69CB389DBef0c130C6296ee271b82f436;
    address mainnetIPNFT = 0xcaD88677CA87a7815728C72D74B4ff4982d54Fc1;

    address vitaDaoTreasury = 0xF5307a74d1550739ef81c6488DC5C7a6a53e5Ac2;

    // paulhaas.eth
    address paulhaas = 0x45602BFBA960277bF917C1b2007D1f03d7bd29e4;

    IPNFT ipnft = IPNFT(mainnetIPNFT);
    Tokenizer tokenizer13;
    IPToken newIPTokenImplementation;

    address alice = makeAddr("alice");

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 20240430);
        vm.selectFork(mainnetFork);
    }

    function upgradeToTokenizer13() public {
        vm.startPrank(mainnetDeployer);
        Tokenizer newTokenizerImplementation = new Tokenizer();
        newIPTokenImplementation = new IPToken();
        vm.stopPrank();

        vm.startPrank(mainnetOwner);
        Tokenizer12 tokenizer12 = Tokenizer12(mainnetTokenizer);
        //todo: make sure that the legacy IPTs are indexed now
        bytes memory upgradeCallData = abi.encodeWithSelector(Tokenizer.reinit.selector, address(newIPTokenImplementation));
        tokenizer12.upgradeToAndCall(address(newTokenizerImplementation), upgradeCallData);
        tokenizer13 = Tokenizer(mainnetTokenizer);
    }

    function testCanUpgradeToV13() public {
        upgradeToTokenizer13();
        assertEq(address(tokenizer13.ipTokenImplementation()), address(newIPTokenImplementation));
        assertEq(address(tokenizer13.permissioner()), 0xC837E02982992B701A1B5e4E21fA01cEB0a628fA);

        vm.startPrank(alice);
        vm.expectRevert("Initializable: contract is already initialized");
        tokenizer13.initialize(IPNFT(address(0)), BlindPermissioner(address(0)));

        vm.expectRevert("Initializable: contract is already initialized");
        newIPTokenImplementation.initialize(2, "Foo", "Bar", alice, "abcde");

        vm.startPrank(mainnetOwner);
        vm.expectRevert("Initializable: contract is already initialized");
        tokenizer13.initialize(IPNFT(address(0)), BlindPermissioner(address(0)));

        vm.expectRevert("Initializable: contract is already initialized");
        tokenizer13.reinit(newIPTokenImplementation);
    }

    function testOldIPTsAreMigratedAndCantBeReminted() public {
        upgradeToTokenizer13();

        assertEq(address(tokenizer13.synthesized(2)), 0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);
        assertEq(address(tokenizer13.synthesized(28)), 0x7b66E84Be78772a3afAF5ba8c1993a1B5D05F9C2);
        assertEq(address(tokenizer13.synthesized(37)), 0xBcE56276591128047313e64744b3EBE03998783f);
        assertEq(address(tokenizer13.synthesized(31415269)), address(0));

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer13.permissioner()));

        address vitaFASTMultisig = 0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555;

        vm.startPrank(vitaFASTMultisig);
        vm.expectRevert(AlreadyTokenized.selector);
        tokenizer13.tokenizeIpnft(2, 1_000_000 ether, "VITA-FAST", "bafkreig274nfj7srmtnb5wd5wlwm3ig2s63wovlz7i3noodjlfz2tm3n5q", bytes(""));

        vm.startPrank(alice);
        vm.expectRevert(MustControlIpnft.selector);
        tokenizer13.tokenizeIpnft(2, 1_000_000 ether, "VITA-FAST", "bafkreig274nfj7srmtnb5wd5wlwm3ig2s63wovlz7i3noodjlfz2tm3n5q", bytes(""));
    }

    function testTokenizeNewIPTs() public {
        upgradeToTokenizer13();
        address valleyDaoMultisig = 0xD920E60b798A2F5a8332799d8a23075c9E77d5F8;
        uint256 valleyDaoIpnftId = 3; //hasnt been tokenized yet
        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer13.permissioner()));

        assertEq(ipnft.ownerOf(valleyDaoIpnftId), valleyDaoMultisig);

        vm.startPrank(valleyDaoMultisig);
        IPToken ipt = tokenizer13.tokenizeIpnft(valleyDaoIpnftId, 1_000_000 ether, "VALLEY", agreementCid, "");
        assertEq(ipt.balanceOf(valleyDaoMultisig), 1_000_000 ether);
        ipt.transfer(alice, 100_000 ether);
        assertEq(ipt.balanceOf(valleyDaoMultisig), 900_000 ether);
        assertEq(ipt.balanceOf(alice), 100_000 ether);

        //controlling the IPT from its own interface
        ipt.issue(valleyDaoMultisig, 1_000_000 ether);
        assertEq(ipt.totalSupply(), 2_000_000 ether);
        assertEq(ipt.balanceOf(valleyDaoMultisig), 1_900_000 ether);

        ipt.cap();

        vm.expectRevert(TokenCapped.selector);
        ipt.issue(valleyDaoMultisig, 100);

        vm.stopPrank();
    }

    function testOldTokensAreStillControllable() public {
        upgradeToTokenizer13();
        address vitaFASTAddress = 0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36;
        address vitaFASTMultisig = 0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555;

        IPToken vitaFast = IPToken(vitaFASTAddress);

        assertEq(vitaFast.balanceOf(paulhaas), 16942857059768483219100);
        assertEq(vitaFast.balanceOf(alice), 0);

        vm.startPrank(paulhaas);
        vitaFast.transfer(alice, 100);
        assertEq(vitaFast.balanceOf(paulhaas), 16942857059768483219000);
        assertEq(vitaFast.balanceOf(alice), 100);
        vm.stopPrank();

        vm.startPrank(vitaFASTMultisig);
        assertEq(vitaFast.totalSupply(), 1_029_555 ether);
        assertEq(vitaFast.balanceOf(vitaFASTMultisig), 13390539642731621592709);
        //the old IPTs allow their original owner to issue more tokens
        vitaFast.issue(vitaFASTMultisig, 100_000 ether);
        assertEq(vitaFast.totalSupply(), 1_129_555 ether);
        assertEq(vitaFast.balanceOf(vitaFASTMultisig), 113390539642731621592709);

        vitaFast.cap();
        vm.expectRevert(TokenCapped.selector);
        vitaFast.issue(vitaFASTMultisig, 100_000 ether);

        /// --- same for VitaRNA, better safe than sorry.
        address vitaRNAAddress = 0x7b66E84Be78772a3afAF5ba8c1993a1B5D05F9C2;
        address vitaRNAMultisig = 0x452f3b60129FdB3cdc78178848c63eC23f38C80d;
        IPToken vitaRna = IPToken(vitaRNAAddress);

        assertEq(vitaRna.balanceOf(paulhaas), 514.411456805927582924 ether);
        assertEq(vitaRna.balanceOf(alice), 0);

        vm.startPrank(paulhaas);
        vitaRna.transfer(alice, 100 ether);
        assertEq(vitaRna.balanceOf(paulhaas), 414.411456805927582924 ether);
        assertEq(vitaRna.balanceOf(alice), 100 ether);
        vm.stopPrank();

        vm.startPrank(vitaRNAMultisig);
        assertEq(vitaRna.totalSupply(), 5_000_000 ether);
        assertEq(vitaRna.balanceOf(vitaRNAMultisig), 200_000 ether);
        vitaRna.issue(vitaRNAMultisig, 100_000 ether);
        assertEq(vitaRna.totalSupply(), 5_100_000 ether);
        assertEq(vitaRna.balanceOf(vitaRNAMultisig), 300_000 ether);

        vitaRna.cap();
        vm.expectRevert(TokenCapped.selector);
        vitaRna.issue(vitaRNAMultisig, 100_000 ether);
    }

    // IPN-21: and the main reason why we're doing all the above
    function testOldTokensCanBeIssuedByNewIPNFTHolder() public {
        upgradeToTokenizer13();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer13.permissioner()));

        address bob = makeAddr("bob");
        address vitaFASTMultisig = 0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555;
        //we're using vita fast's original abi here. It actually is call-compatible to IPToken, but this is the ultimate legacy test
        IPToken12 vitaFAST12 = IPToken12(0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);
        IPToken vitaFAST13 = IPToken(0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);

        vm.startPrank(vitaFASTMultisig);
        ipnft.transferFrom(vitaFASTMultisig, alice, 2);
        assertEq(ipnft.ownerOf(2), alice);

        vm.startPrank(alice);
        // This is new: originally Alice *would* indeed have been able to do this:
        vm.expectRevert(AlreadyTokenized.selector);
        tokenizer13.tokenizeIpnft(2, 1_000_000 ether, "VITA-FAST", "imfeelingfunny", bytes(""));

        assertEq(vitaFAST12.balanceOf(alice), 0);

        //this *should* be possible but can't work due to the old implementation
        vm.expectRevert(OnlyIssuerOrOwner.selector);
        vitaFAST12.issue(alice, 1_000_000 ether);
        //the selector of course doesnt exist on the new interface, but the implementation reverts with it:
        vm.expectRevert(OnlyIssuerOrOwner.selector);
        vitaFAST13.issue(alice, 1_000_000 ether);

        //to issue new tokens, alice uses the Tokenizer instead:
        tokenizer13.issue(vitaFAST13, 1_000_000 ether, alice);
        assertEq(vitaFAST12.balanceOf(alice), 1_000_000 ether);

        //due to the original implementation, the original owner can still issue tokens and we cannot do anything about it:
        vm.startPrank(vitaFASTMultisig);
        vitaFAST12.issue(bob, 1_000_000 ether);
        assertEq(vitaFAST12.balanceOf(bob), 1_000_000 ether);
        assertEq(vitaFAST13.balanceOf(bob), 1_000_000 ether);

        // but they cannot do that using the tokenizer:
        vm.expectRevert(MustControlIpnft.selector);
        tokenizer13.issue(vitaFAST13, 1_000_000 ether, alice);
        vm.expectRevert(MustControlIpnft.selector);
        tokenizer13.cap(vitaFAST13);

        //but they unfortunately also can cap the token:
        vitaFAST12.cap();

        vm.startPrank(alice);
        vm.expectRevert(TokenCapped.selector);
        tokenizer13.issue(vitaFAST13, 1_000_000 ether, alice);
    }
}

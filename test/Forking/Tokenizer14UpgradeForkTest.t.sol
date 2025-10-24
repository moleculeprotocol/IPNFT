// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IPNFT } from "../../src/IPNFT.sol";

import { Metadata } from "../../src/IIPToken.sol";

import { IIPToken } from "../../src/IIPToken.sol";
import { IPToken, TokenCapped } from "../../src/IPToken.sol";

import { BlindPermissioner, IPermissioner } from "../../src/Permissioner.sol";
import { AlreadyTokenized, MustControlIpnft, Tokenizer } from "../../src/Tokenizer.sol";
import { WrappedIPToken } from "../../src/WrappedIPToken.sol";

import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { OnlyIssuerOrOwner } from "../../src/helpers/test-upgrades/IPToken12.sol";
import { IPToken13 } from "../../src/helpers/test-upgrades/IPToken13.sol";
import { Tokenizer13 } from "../../src/helpers/test-upgrades/Tokenizer13.sol";

import { AcceptAllAuthorizer } from "../helpers/AcceptAllAuthorizer.sol";

contract Tokenizer14UpgradeForkTest is Test {
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
    Tokenizer tokenizer14;
    IPToken newIPTokenImplementation;
    WrappedIPToken newWrappedIPTokenImplementation;

    address alice = makeAddr("alice");

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 23367545);
        vm.selectFork(mainnetFork);
    }

    function upgradeToTokenizer14() public {
        vm.startPrank(mainnetDeployer);
        Tokenizer newTokenizerImplementation = new Tokenizer();
        newIPTokenImplementation = new IPToken();
        newWrappedIPTokenImplementation = new WrappedIPToken();
        vm.stopPrank();

        vm.startPrank(mainnetOwner);
        Tokenizer13 tokenizer13 = Tokenizer13(mainnetTokenizer);
        // Updated for V14: reinit now takes both IPToken and WrappedIPToken implementations
        bytes memory upgradeCallData =
            abi.encodeWithSelector(Tokenizer.reinit.selector, address(newWrappedIPTokenImplementation), address(newIPTokenImplementation));
        tokenizer13.upgradeToAndCall(address(newTokenizerImplementation), upgradeCallData);
        tokenizer14 = Tokenizer(mainnetTokenizer);

        // Set up AcceptAllAuthorizer for IPNFT minting in tests
        AcceptAllAuthorizer authorizer = new AcceptAllAuthorizer();
        ipnft.setAuthorizer(authorizer);
        vm.stopPrank();
    }

    function testCanUpgradeToV14() public {
        upgradeToTokenizer14();
        assertEq(address(tokenizer14.ipTokenImplementation()), address(newIPTokenImplementation));
        assertEq(address(tokenizer14.wrappedTokenImplementation()), address(newWrappedIPTokenImplementation));
        assertEq(address(tokenizer14.permissioner()), 0xC837E02982992B701A1B5e4E21fA01cEB0a628fA);

        vm.startPrank(alice);
        vm.expectRevert("Initializable: contract is already initialized");
        tokenizer14.initialize(IPNFT(address(0)), BlindPermissioner(address(0)));

        vm.expectRevert("Initializable: contract is already initialized");
        newIPTokenImplementation.initialize(2, "Foo", "Bar", alice, "abcde");

        vm.startPrank(mainnetOwner);
        vm.expectRevert("Initializable: contract is already initialized");
        tokenizer14.initialize(IPNFT(address(0)), BlindPermissioner(address(0)));

        vm.expectRevert("Initializable: contract is already initialized");
        tokenizer14.reinit(newWrappedIPTokenImplementation, newIPTokenImplementation);
    }

    function testOldIPTsAreMigratedAndCantBeReminted() public {
        upgradeToTokenizer14();

        assertEq(address(tokenizer14.synthesized(2)), 0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);
        assertEq(address(tokenizer14.synthesized(28)), 0x7b66E84Be78772a3afAF5ba8c1993a1B5D05F9C2);
        assertEq(address(tokenizer14.synthesized(37)), 0xBcE56276591128047313e64744b3EBE03998783f);
        assertEq(address(tokenizer14.synthesized(31415269)), address(0));

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        // Check who actually owns IPNFT #2 at this block
        address currentOwner = ipnft.ownerOf(2);

        vm.startPrank(currentOwner);
        vm.expectRevert(AlreadyTokenized.selector);
        tokenizer14.tokenizeIpnft(2, 1_000_000 ether, "VITA-FAST", "bafkreig274nfj7srmtnb5wd5wlwm3ig2s63wovlz7i3noodjlfz2tm3n5q", bytes(""));

        vm.startPrank(alice);
        vm.expectRevert(MustControlIpnft.selector);
        tokenizer14.tokenizeIpnft(2, 1_000_000 ether, "VITA-FAST", "bafkreig274nfj7srmtnb5wd5wlwm3ig2s63wovlz7i3noodjlfz2tm3n5q", bytes(""));
    }

    function testOldTokensCanBeUsedAfterUpgrade() public {
        upgradeToTokenizer14();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        IPToken ipt = IPToken(0xBcE56276591128047313e64744b3EBE03998783f);

        // Note: At this block, the token distribution may be different
        // Let's check the actual total supply and who has balances
        assertEq(ipt.totalSupply(), 1_000_000 ether);

        // Find someone with balance to test transfers
        // Check if paulhaas has any balance in this token as well
        uint256 paulhaasBalance = ipt.balanceOf(paulhaas);
        if (paulhaasBalance >= 100_000 ether) {
            vm.startPrank(paulhaas);
            assertEq(ipt.balanceOf(alice), 0);

            ipt.transfer(alice, 100_000 ether);
            assertEq(ipt.balanceOf(paulhaas), paulhaasBalance - 100_000 ether);
            assertEq(ipt.balanceOf(alice), 100_000 ether);
            vm.stopPrank();
        }

        /// --- same for VitaFAST, better safe than sorry.
        address vitaFASTAddress = 0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36;
        address vitaFASTMultisig = 0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555;
        IPToken vitaFast = IPToken(vitaFASTAddress);

        uint256 paulhaasInitialBalance = vitaFast.balanceOf(paulhaas);
        assertEq(vitaFast.balanceOf(alice), 0);

        // Only test transfer if paulhaas has enough balance
        if (paulhaasInitialBalance >= 100_000 ether) {
            vm.startPrank(paulhaas);
            vitaFast.transfer(alice, 100_000 ether);
            assertEq(vitaFast.balanceOf(paulhaas), paulhaasInitialBalance - 100_000 ether);
            assertEq(vitaFast.balanceOf(alice), 100_000 ether);
            vm.stopPrank();
        }

        vm.startPrank(vitaFASTMultisig);
        uint256 initialTotalSupply = vitaFast.totalSupply();
        uint256 multisigInitialBalance = vitaFast.balanceOf(vitaFASTMultisig);

        //the old IPTs allow their original owner to issue more tokens
        vitaFast.issue(vitaFASTMultisig, 100_000 ether);
        assertEq(vitaFast.totalSupply(), initialTotalSupply + 100_000 ether);
        assertEq(vitaFast.balanceOf(vitaFASTMultisig), multisigInitialBalance + 100_000 ether);

        vitaFast.cap();
        vm.expectRevert(TokenCapped.selector);
        vitaFast.issue(vitaFASTMultisig, 100_000 ether);

        /// --- same for VitaRNA, better safe than sorry.
        address vitaRNAAddress = 0x7b66E84Be78772a3afAF5ba8c1993a1B5D05F9C2;
        address vitaRNAMultisig = 0x452f3b60129FdB3cdc78178848c63eC23f38C80d;
        IPToken vitaRna = IPToken(vitaRNAAddress);

        uint256 paulhaasRnaBalance = vitaRna.balanceOf(paulhaas);
        assertEq(vitaRna.balanceOf(alice), 0);

        // Only test transfer if paulhaas has enough balance
        if (paulhaasRnaBalance >= 100 ether) {
            vm.startPrank(paulhaas);
            vitaRna.transfer(alice, 100 ether);
            assertEq(vitaRna.balanceOf(paulhaas), paulhaasRnaBalance - 100 ether);
            assertEq(vitaRna.balanceOf(alice), 100 ether);
            vm.stopPrank();
        }

        vm.startPrank(vitaRNAMultisig);
        uint256 rnaInitialTotalSupply = vitaRna.totalSupply();
        uint256 rnaMultisigInitialBalance = vitaRna.balanceOf(vitaRNAMultisig);

        vitaRna.issue(vitaRNAMultisig, 100_000 ether);
        assertEq(vitaRna.totalSupply(), rnaInitialTotalSupply + 100_000 ether);
        assertEq(vitaRna.balanceOf(vitaRNAMultisig), rnaMultisigInitialBalance + 100_000 ether);

        vitaRna.cap();
        vm.expectRevert(TokenCapped.selector);
        vitaRna.issue(vitaRNAMultisig, 100_000 ether);
    }

    // IPN-21: and the main reason why we're doing all the above
    function testOldTokensCanBeIssuedByNewIPNFTHolder() public {
        upgradeToTokenizer14();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        address bob = makeAddr("bob");
        //we're using vita fast's original interface here for legacy compatibility testing
        IPToken vitaFAST = IPToken(0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);

        // Check who currently owns IPNFT #2 at this block
        address currentOwner = ipnft.ownerOf(2);

        vm.startPrank(currentOwner);
        ipnft.transferFrom(currentOwner, alice, 2);
        assertEq(ipnft.ownerOf(2), alice);

        vm.startPrank(alice);
        // This is new: originally Alice *would* indeed have been able to do this:
        vm.expectRevert(AlreadyTokenized.selector);
        tokenizer14.tokenizeIpnft(2, 1_000_000 ether, "VITA-FAST", "imfeelingfunny", bytes(""));

        assertEq(vitaFAST.balanceOf(alice), 0);

        //this *should* be possible but can't work due to the old implementation
        vm.expectRevert(OnlyIssuerOrOwner.selector);
        vitaFAST.issue(alice, 1_000_000 ether);

        //to issue new tokens, alice uses the Tokenizer instead:
        tokenizer14.issue(vitaFAST, 1_000_000 ether, alice);
        assertEq(vitaFAST.balanceOf(alice), 1_000_000 ether);

        //due to the original implementation, the current owner (who is not the original issuer) cannot issue tokens directly:
        vm.startPrank(currentOwner);
        vm.expectRevert(OnlyIssuerOrOwner.selector);
        vitaFAST.issue(bob, 1_000_000 ether);

        // but they cannot do that using the tokenizer (since they're no longer the IPNFT owner):
        vm.expectRevert(MustControlIpnft.selector);
        tokenizer14.issue(vitaFAST, 1_000_000 ether, alice);
        vm.expectRevert(MustControlIpnft.selector);
        tokenizer14.cap(vitaFAST);

        // Alice (new IPNFT owner) can use tokenizer to cap the token:
        vm.startPrank(alice);
        tokenizer14.cap(vitaFAST);

        vm.expectRevert(TokenCapped.selector);
        tokenizer14.issue(vitaFAST, 1_000_000 ether, alice);
    }

    function testNewIPTokensHaveEnhancedInterface() public {
        upgradeToTokenizer14();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        // Mint a new IPNFT for testing
        vm.startPrank(alice);
        vm.deal(alice, MINTING_FEE);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(alice, reservationId, ipfsUri, DEFAULT_SYMBOL, bytes(""));
        uint256 newIpnftId = reservationId;

        // Tokenize it with the new implementation
        IPToken newToken = tokenizer14.tokenizeIpnft(newIpnftId, 1_000_000 ether, "NEW-IPT", agreementCid, bytes(""));

        // Test that the new token implements IIPToken interface functions
        IIPToken iiptToken = IIPToken(address(newToken));

        // Test interface functions work
        assertEq(newToken.name(), string.concat("IP Tokens of IPNFT #", vm.toString(newIpnftId)));
        assertEq(newToken.symbol(), "NEW-IPT");
        assertEq(newToken.decimals(), 18);
        assertEq(newToken.balanceOf(alice), 1_000_000 ether);
        assertEq(iiptToken.totalIssued(), 1_000_000 ether);

        // Test that metadata is accessible through interface
        Metadata memory metadata = iiptToken.metadata();
        assertEq(metadata.ipnftId, newIpnftId);
        assertEq(metadata.originalOwner, alice);
        assertEq(metadata.agreementCid, agreementCid);

        // Test URI function
        string memory uri = iiptToken.uri();
        assertTrue(bytes(uri).length > 0);

        vm.stopPrank();
    }

    function testLegacyTokensStillWorkWithoutFullInterface() public {
        upgradeToTokenizer14();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        // Use existing legacy token (VitaFAST)
        IPToken legacyToken = IPToken(0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);

        // Check who currently owns IPNFT #2 at this block
        address currentOwner = ipnft.ownerOf(2);

        // Basic ERC20 functions should work (legacy tokens use "Molecules" naming)
        assertEq(legacyToken.name(), "Molecules of IPNFT #2");
        assertEq(legacyToken.symbol(), "VITA-FAST");
        assertEq(legacyToken.decimals(), 18);
        assertTrue(legacyToken.balanceOf(currentOwner) > 0);

        // Test that we can still control legacy tokens through the tokenizer
        vm.startPrank(currentOwner);
        // Transfer IPNFT to alice first
        ipnft.transferFrom(currentOwner, alice, 2);

        vm.startPrank(alice);
        // Alice should be able to issue more tokens through the tokenizer
        uint256 beforeBalance = legacyToken.balanceOf(alice);
        tokenizer14.issue(legacyToken, 100_000 ether, alice);
        assertEq(legacyToken.balanceOf(alice), beforeBalance + 100_000 ether);

        vm.stopPrank();
    }

    function testInterfaceCompatibilityForNewTokens() public {
        upgradeToTokenizer14();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        // Create a new token
        vm.startPrank(alice);
        vm.deal(alice, MINTING_FEE);
        uint256 reservationId2 = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(alice, reservationId2, ipfsUri, DEFAULT_SYMBOL, bytes(""));
        uint256 newIpnftId = reservationId2;

        IPToken newToken = tokenizer14.tokenizeIpnft(newIpnftId, 500_000 ether, "COMPAT-TEST", agreementCid, bytes(""));

        // Test that both IPToken and IIPToken interfaces work identically
        IIPToken interfaceToken = IIPToken(address(newToken));

        // Compare results from both interfaces (only IP-specific functions available on interface)
        assertEq(newToken.totalIssued(), interfaceToken.totalIssued());

        // Test metadata access
        Metadata memory directMetadata = newToken.metadata();
        Metadata memory interfaceMetadata = interfaceToken.metadata();

        assertEq(directMetadata.ipnftId, interfaceMetadata.ipnftId);
        assertEq(directMetadata.originalOwner, interfaceMetadata.originalOwner);
        assertEq(directMetadata.agreementCid, interfaceMetadata.agreementCid);

        vm.stopPrank();
    }

    function testAttachExistingERC20AsWrappedIPToken() public {
        upgradeToTokenizer14();

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(tokenizer14.permissioner()));

        // Mint a new IPNFT for testing the attach functionality
        vm.startPrank(alice);
        vm.deal(alice, MINTING_FEE);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(alice, reservationId, ipfsUri, DEFAULT_SYMBOL, bytes(""));
        uint256 newIpnftId = reservationId;

        // Deploy a test ERC20 token to attach
        FakeERC20 testToken = new FakeERC20("Test Wrapped Token", "TWT");
        testToken.mint(alice, 5_000_000 ether);

        // Verify initial state
        assertEq(testToken.balanceOf(alice), 5_000_000 ether);
        assertEq(testToken.name(), "Test Wrapped Token");
        assertEq(testToken.symbol(), "TWT");
        assertEq(testToken.decimals(), 18);

        // Attach the ERC20 token to the IPNFT using the new V14 functionality
        IIPToken wrappedToken = tokenizer14.attachIpt(newIpnftId, agreementCid, bytes(""), testToken);

        // Verify the wrapped token was created correctly
        assertTrue(address(wrappedToken) != address(0));
        assertTrue(address(wrappedToken) != address(testToken));
        assertEq(address(tokenizer14.synthesized(newIpnftId)), address(wrappedToken));

        // Test the wrapped token implements IIPToken interface
        WrappedIPToken wrappedImpl = WrappedIPToken(address(wrappedToken));
        assertEq(wrappedImpl.name(), "Test Wrapped Token");
        assertEq(wrappedImpl.symbol(), "TWT");
        assertEq(wrappedImpl.decimals(), 18);
        assertEq(wrappedImpl.balanceOf(alice), 5_000_000 ether);
        assertEq(wrappedToken.totalIssued(), 5_000_000 ether);

        // Test metadata is accessible through interface
        Metadata memory metadata = wrappedToken.metadata();
        assertEq(metadata.ipnftId, newIpnftId);
        assertEq(metadata.originalOwner, alice);
        assertEq(metadata.agreementCid, agreementCid);

        // Test URI function
        string memory uri = wrappedToken.uri();
        assertTrue(bytes(uri).length > 0);

        // Test that the underlying ERC20 token is still functional
        assertEq(testToken.balanceOf(alice), 5_000_000 ether);

        // Test that wrapped tokens cannot issue or cap (they should delegate to underlying token)
        vm.expectRevert(); // WrappedIPToken should not allow issue/cap operations
        WrappedIPToken(address(wrappedToken)).issue(alice, 1000 ether);

        vm.expectRevert(); // WrappedIPToken should not allow cap operations
        WrappedIPToken(address(wrappedToken)).cap();

        // Test that WrappedIPToken only implements IIPToken state-changing operations (which revert)
        // ERC20 state-changing functions are no longer implemented

        // Test that we cannot attach another token to the same IPNFT
        FakeERC20 anotherToken = new FakeERC20("Another Token", "ANT");
        vm.expectRevert(AlreadyTokenized.selector);
        tokenizer14.attachIpt(newIpnftId, agreementCid, bytes(""), anotherToken);

        vm.stopPrank();
    }
}

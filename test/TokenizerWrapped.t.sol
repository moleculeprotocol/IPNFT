// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { Tokenizer, ZeroAddress, InvalidTokenContract, InvalidTokenDecimals } from "../src/Tokenizer.sol";
import { IIPToken } from "../src/IIPToken.sol";
import { IPToken } from "../src/IPToken.sol";
import { WrappedIPToken } from "../src/WrappedIPToken.sol";
import { IPermissioner, BlindPermissioner } from "../src/Permissioner.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Test helper contract with invalid decimals
contract FakeERC20WithInvalidDecimals {
    function decimals() external pure returns (uint8) {
        return 25; // Invalid: > 18
    }

    function name() external pure returns (string memory) {
        return "Invalid Token";
    }

    function symbol() external pure returns (string memory) {
        return "INVALID";
    }

    function totalSupply() external pure returns (uint256) {
        return 1000000 ether;
    }
}

contract TokenizerWrappedTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "IPT-0001";

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");

    //Alice, Bob and Charlie are molecules holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");
    uint256 bobPk;

    IPNFT internal ipnft;
    Tokenizer internal tokenizer;

    IPermissioner internal blindPermissioner;
    FakeERC20 internal erc20;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        vm.startPrank(deployer);

        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());
        blindPermissioner = new BlindPermissioner();

        tokenizer = Tokenizer(address(new ERC1967Proxy(address(new Tokenizer()), "")));
        tokenizer.initialize(ipnft, blindPermissioner);
        tokenizer.setIPTokenImplementation(new IPToken());
        tokenizer.setWrappedIPTokenImplementation(new WrappedIPToken());

        vm.stopPrank();

        vm.deal(originalOwner, MINTING_FEE);
        vm.startPrank(originalOwner);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, "");
    }

    function testAdoptERC20AsWrappedIPToken() public {
        vm.startPrank(originalOwner);
        erc20 = new FakeERC20("URORiif", "UROR");
        erc20.mint(originalOwner, 1_000_000 ether);

        IIPToken tokenContract = tokenizer.attachIpt(1, agreementCid, "", erc20);

        assertEq(tokenContract.balanceOf(originalOwner), 1_000_000 ether);
        assertNotEq(address(tokenizer.synthesized(1)), address(erc20)); // the synthesized member tracks the wrapped ipt
        assertEq(tokenContract.totalIssued(), 1_000_000 ether);
        assertEq(tokenContract.name(), "URORiif");
    }

    function testCannotAttachInvalidTokenContract() public {
        vm.startPrank(originalOwner);

        // Test with zero address
        vm.expectRevert(ZeroAddress.selector);
        tokenizer.attachIpt(1, agreementCid, "", IERC20Metadata(address(0)));

        // Test with non-contract address
        vm.expectRevert(InvalidTokenContract.selector);
        tokenizer.attachIpt(1, agreementCid, "", IERC20Metadata(alice));
    }

    function testCannotAttachTokenWithInvalidDecimals() public {
        vm.startPrank(originalOwner);

        // Deploy a token with invalid decimals (>18)
        FakeERC20WithInvalidDecimals invalidToken = new FakeERC20WithInvalidDecimals();

        vm.expectRevert(InvalidTokenDecimals.selector);
        tokenizer.attachIpt(1, agreementCid, "", IERC20Metadata(address(invalidToken)));
    }

    function testWrappedTokenProperties() public {
        vm.startPrank(originalOwner);
        erc20 = new FakeERC20("TestToken", "TEST");
        erc20.mint(originalOwner, 1_000_000 ether);

        IIPToken tokenContract = tokenizer.attachIpt(1, agreementCid, "", erc20);
        WrappedIPToken wrappedToken = WrappedIPToken(address(tokenContract));

        // Verify wrapped token properties
        assertEq(address(wrappedToken.wrappedToken()), address(erc20));
        assertEq(tokenContract.balanceOf(originalOwner), 1_000_000 ether);
        assertEq(tokenContract.totalIssued(), 1_000_000 ether);
        assertEq(tokenContract.name(), "TestToken");
        assertEq(tokenContract.symbol(), "TEST");
    }

    function testWrappedTokenCannotIssueOrCap() public {
        vm.startPrank(originalOwner);
        erc20 = new FakeERC20("TestToken", "TEST");
        erc20.mint(originalOwner, 1_000_000 ether);

        IIPToken tokenContract = tokenizer.attachIpt(1, agreementCid, "", erc20);

        // Wrapped tokens should not be able to issue or cap
        vm.expectRevert("WrappedIPToken: cannot issue");
        tokenContract.issue(alice, 1000);

        vm.expectRevert("WrappedIPToken: cannot cap");
        tokenContract.cap();
    }

    // Helper function to check if a string contains a substring
    function contains(string memory source, string memory search) internal pure returns (bool) {
        bytes memory sourceBytes = bytes(source);
        bytes memory searchBytes = bytes(search);

        if (searchBytes.length > sourceBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= sourceBytes.length - searchBytes.length; i++) {
            bool found = true;

            for (uint256 j = 0; j < searchBytes.length; j++) {
                if (sourceBytes[i + j] != searchBytes[j]) {
                    found = false;
                    break;
                }
            }

            if (found) {
                return true;
            }
        }

        return false;
    }
}

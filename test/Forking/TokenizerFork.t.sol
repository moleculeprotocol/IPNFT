// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

//import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IPNFT } from "../../src/IPNFT.sol";

import { MustOwnIpnft, AlreadyTokenized, Tokenizer } from "../../src/Tokenizer.sol";
import { Tokenizer11 } from "../../src/helpers/test-upgrades/Tokenizer11.sol";
import { IPToken, OnlyIssuerOrOwner, TokenCapped } from "../../src/IPToken.sol";
import { IPermissioner, BlindPermissioner } from "../../src/Permissioner.sol";

//import { SchmackoSwap, ListingState } from "../../src/SchmackoSwap.sol";

contract TokenizerForkTest is Test {
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

    // old IP Token implementation
    address vitaFASTAddress = 0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36;

    // https://app.safe.global/home?safe=eth:0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555
    address vitaFASTMultisig = 0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555;

    // paulhaas.eth
    address paulhaas = 0x45602BFBA960277bF917C1b2007D1f03d7bd29e4;

    // ValleyDAO multisig
    address valleyDaoMultisig = 0xD920E60b798A2F5a8332799d8a23075c9E77d5F8;

    // ValleyDAO IPNFT
    uint256 valleyDaoIpnftId = 3;

    address alice = makeAddr("alice");

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 18968463);
        vm.selectFork(mainnetFork);
    }

    function testCanUpgradeErc20TokenImplementation() public {
        IPNFT ipnftMainnetInstance = IPNFT(mainnetIPNFT);
        Tokenizer11 tokenizer11 = Tokenizer11(mainnetTokenizer);

        vm.startPrank(mainnetDeployer);
        Tokenizer newTokenizerImplementation = new Tokenizer();
        IPToken newIPTokenImplementation = new IPToken();
        vm.stopPrank();

        vm.startPrank(mainnetOwner);
        bytes memory upgradeCallData = abi.encodeWithSelector(Tokenizer.setIPTokenImplementation.selector, address(newIPTokenImplementation));
        tokenizer11.upgradeToAndCall(address(newTokenizerImplementation), upgradeCallData);
        Tokenizer upgradedTokenizer = Tokenizer(mainnetTokenizer);

        assertEq(address(upgradedTokenizer.ipTokenImplementation()), address(newIPTokenImplementation));

        deployCodeTo("Permissioner.sol:BlindPermissioner", "", address(upgradedTokenizer.permissioner()));
        vm.stopPrank();

        assertEq(ipnftMainnetInstance.ownerOf(valleyDaoIpnftId), valleyDaoMultisig);

        vm.startPrank(valleyDaoMultisig);
        IPToken ipt = upgradedTokenizer.tokenizeIpnft(valleyDaoIpnftId, 1_000_000 ether, "IPT", agreementCid, "");
        assertEq(ipt.balanceOf(valleyDaoMultisig), 1_000_000 ether);
        ipt.transfer(alice, 100_000 ether);

        assertEq(ipt.balanceOf(valleyDaoMultisig), 900_000 ether);

        ipt.issue(valleyDaoMultisig, 1_000_000 ether);
        assertEq(ipt.totalSupply(), 2_000_000 ether);
        assertEq(ipt.balanceOf(valleyDaoMultisig), 1_900_000 ether);

        ipt.cap();

        vm.expectRevert(TokenCapped.selector);
        ipt.issue(valleyDaoMultisig, 100);

        vm.stopPrank();

        IPToken vitaFast = IPToken(vitaFASTAddress);

        assertEq(vitaFast.balanceOf(paulhaas), 16942857059768483219100);
        assertEq(vitaFast.balanceOf(alice), 0);

        vm.startPrank(paulhaas);
        vitaFast.transfer(alice, 100);
        assertEq(vitaFast.balanceOf(paulhaas), 16942857059768483219000);
        assertEq(vitaFast.balanceOf(alice), 100);
        vm.stopPrank();

        vm.startPrank(vitaFASTMultisig);
        assertEq(vitaFast.balanceOf(vitaFASTMultisig), 16940676213630533216614);
        vitaFast.issue(vitaFASTMultisig, 100_000 ether);
        assertEq(vitaFast.totalSupply(), 1129555 ether);
        assertEq(vitaFast.balanceOf(vitaFASTMultisig), 116940676213630533216614);
        vitaFast.cap();
        vm.expectRevert(TokenCapped.selector);
        vitaFast.issue(vitaFASTMultisig, 100_000 ether);
    }
}

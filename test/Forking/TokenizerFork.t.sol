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
import "../helpers/MakeGnosisWallet.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { AcceptAllAuthorizer } from "../helpers/AcceptAllAuthorizer.sol";

import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { MustOwnIpnft, AlreadyTokenized, Tokenizer } from "../../src/Tokenizer.sol";
import { Tokenizer11 } from "../../src/helpers/test-upgrades/Tokenizer11.sol";

import { IPToken, OnlyIssuerOrOwner, TokenCapped } from "../../src/IPToken.sol";
import { Molecules } from "../../src/helpers/test-upgrades/Molecules.sol";
import { Synthesizer } from "../../src/helpers/test-upgrades/Synthesizer.sol";
import { IPermissioner, BlindPermissioner } from "../../src/Permissioner.sol";

import { SchmackoSwap, ListingState } from "../../src/SchmackoSwap.sol";

contract TokenizerTest is Test {
    using SafeERC20Upgradeable for IPToken;
    uint256 mainnetFork;


    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "IPT-0001";

    address mainnetOwner = 0xCfA0F84660fB33bFd07C369E5491Ab02C449f71B;
    address mainnetTokenizer = 0x58EB89C69CB389DBef0c130C6296ee271b82f436;
    address mainnetIPNFT = 0xcaD88677CA87a7815728C72D74B4ff4982d54Fc1;
    
    address vitaFAST = 0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36;
    address vitaFastIssuer = 0xf7990CD398daFB4fe5Fd6B9228B8e6f72b296555;
    address vitaFastHolder = 0x45602BFBA960277bF917C1b2007D1f03d7bd29e4;


    address ipnftHolder = 0xD920E60b798A2F5a8332799d8a23075c9E77d5F8;
    uint256 ipNftIdOfHolder = 3;

    //Alice, Bob and Charlie are molecules holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    function setUp() public {
        mainnetFork = vm.createFork(
            vm.envString("MAINNET_RPC_URL"),
            18968463
        );
        (alice, alicePk) = makeAddrAndKey("alice");
    }


    function testCanUpgradeErc20TokenImplementation() public {
        vm.selectFork(mainnetFork);

        IPNFT ipnftMainnetInstance = IPNFT(mainnetIPNFT);

        IPToken newIPTokenImplementation = new IPToken();
        
        vm.startPrank(mainnetOwner); // Owner address on mainnet
        Tokenizer11 tokenizer11 = Tokenizer11(mainnetTokenizer);

        bytes memory data = abi.encodeWithSignature("setIPTokenImplementation(address)", address(newIPTokenImplementation));

        tokenizer11.upgradeToAndCall(address(new Tokenizer()), data);
        Tokenizer upgradedTokenizer = Tokenizer(mainnetTokenizer);

        //upgradedTokenizer.setIPTokenImplementation(address(newIPTokenImplementation));
        assertEq(upgradedTokenizer.ipTokenImplementation(), address(newIPTokenImplementation));
        
        IPermissioner _permissioner = new BlindPermissioner();
        upgradedTokenizer.reinit(_permissioner); // project is already initialized
        vm.stopPrank();

        assertEq(ipnftMainnetInstance.ownerOf(ipNftIdOfHolder), ipnftHolder);
        
        vm.startPrank(ipnftHolder);
        IPToken createdIPToken =  upgradedTokenizer.tokenizeIpnft(3, 100_000, "IPT", agreementCid, "");
        assertEq(createdIPToken.balanceOf(ipnftHolder), 100_000);
        createdIPToken.transfer(alice, 1);
        assertEq(createdIPToken.balanceOf(ipnftHolder), 99_999);
        uint256 createdIPTokenTotalSupply = createdIPToken.totalSupply();
        createdIPToken.issue(ipnftHolder, 10);
        assertEq(createdIPToken.totalSupply(), createdIPTokenTotalSupply + 10);

        createdIPToken.cap();
        vm.expectRevert();
        createdIPToken.issue(ipnftHolder, 100);

        vm.stopPrank();

        IPToken vitaFastInstance = IPToken(vitaFAST);
       
        vm.startPrank(vitaFastHolder);
        uint256 vitaFastHolderBalance1 = vitaFastInstance.balanceOf(vitaFastHolder);
        uint256 aliceBalance1 = vitaFastInstance.balanceOf(alice);
        vitaFastInstance.transfer(alice, 100);
        assertEq(vitaFastInstance.balanceOf(vitaFastHolder), vitaFastHolderBalance1 - 100);
        assertEq(vitaFastInstance.balanceOf(alice), aliceBalance1 + 100);
        vm.stopPrank();

        vm.startPrank(vitaFastIssuer);
        uint256 vitaFastSupply1 = vitaFastInstance.totalSupply();
        vitaFastInstance.issue(vitaFastIssuer, 10);
        assertEq(vitaFastInstance.totalSupply(), vitaFastSupply1 + 10);

        vitaFastInstance.cap();
        vm.expectRevert();
        vitaFastInstance.issue(vitaFastIssuer, 100);
        //IPToken exampleVitaFast = IPToken(0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);
        //exampleVitaFast.transfer(alice, 100 wei);


        //vm.stopPrank();


    //     assertEq(tokenContractOld.balanceOf(originalOwner), 100_000);

    //     vm.deal(originalOwner, MINTING_FEE);
    //     vm.startPrank(originalOwner);
    //     uint256 reservationId = ipnft.reserve();
    //     ipnft.mintReservation{ value: MINTING_FEE }(originalOwner, reservationId, ipfsUri, DEFAULT_SYMBOL, "");
    //     IPToken tokenContractNew = synth2.tokenizeIpnft(2, 70_000, agreementCid, "");
    //     vm.stopPrank();

    //     assertEq(tokenContractNew.balanceOf(originalOwner), 70_000);

    //     IPTokenNext newTokenImpl = IPTokenNext(address(tokenContractNew));

    //     newTokenImpl.setAStateVar(42);
    //     assertEq(newTokenImpl.aNewStateVar(), 42);

    //     IPTokenNext oldTokenImplWrapped = IPTokenNext(address(tokenContractOld));
    //     vm.expectRevert();
    //     oldTokenImplWrapped.setAStateVar(42);
    }
}

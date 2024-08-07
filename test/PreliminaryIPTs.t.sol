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
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { MustControlIpnft, AlreadyTokenized, Tokenizer, ZeroAddress, IPTNotControlledByTokenizer } from "../src/Tokenizer.sol";

import { IPToken, TokenCapped, Metadata as TokenMetadata } from "../src/IPToken.sol";
import { IControlIPTs } from "../src/IControlIPTs.sol";
import { Molecules } from "../src/helpers/test-upgrades/Molecules.sol";
import { Synthesizer } from "../src/helpers/test-upgrades/Synthesizer.sol";
import { IPermissioner, BlindPermissioner } from "../src/Permissioner.sol";

contract PreliminaryIPTsTest is Test {
    using SafeERC20Upgradeable for IPToken;

    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    string agreementCid = "bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq";
    uint256 MINTING_FEE = 0.001 ether;
    string DEFAULT_SYMBOL = "IPT-0001";

    address deployer = makeAddr("chucknorris");
    address originalOwner = makeAddr("brucelee");
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    IPNFT internal ipnft;
    Tokenizer internal tokenizer;

    IPermissioner internal blindPermissioner;
    FakeERC20 internal erc20;

    function setUp() public {
        vm.startPrank(deployer);
        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());
        blindPermissioner = new BlindPermissioner();

        tokenizer = Tokenizer(address(new ERC1967Proxy(address(new Tokenizer()), "")));
        tokenizer.initialize(ipnft, blindPermissioner);
        tokenizer.setIPTokenImplementation(new IPToken());
    }

    function testReserveAndIssue() public {
        vm.startPrank(originalOwner);
        (uint256 reservationId, IPToken ipToken) = tokenizer.reserveNewIpnftIdAndTokenize(1_000_000 ether, "IPT-SOL-FOO", "QmAgreeToThat", "");

        vm.expectRevert("ERC721: invalid token ID");
        ipnft.ownerOf(reservationId);

        assertEq(ipToken.balanceOf(originalOwner), 1_000_000 ether);

        //even direct minting works now ... //todo: check if this is intended or if we must prevent this
        ipToken.issue(bob, 42 ether);
        assertEq(ipToken.balanceOf(bob), 42 ether);

        // ... do anything with the ip token ...

        vm.startPrank(bob); //bob didn't reserve this.
        vm.expectRevert(abi.encodeWithSelector(IPNFT.NotOwningReservation.selector, 1));
        ipnft.mintReservation(alice, reservationId, ipfsUri, "A-TOTALLY-DIFFERENT-SYMBOL", "");

        vm.startPrank(originalOwner);
        vm.deal(originalOwner, 0.1 ether);
        ipnft.mintReservation{ value: 0.1 ether }(alice, reservationId, ipfsUri, "A-TOTALLY-DIFFERENT-SYMBOL", "");

        assertEq(ipnft.ownerOf(reservationId), alice);

        vm.startPrank(alice);
        ipToken.issue(bob, 58 ether);
        assertEq(ipToken.balanceOf(bob), 100 ether);
    }
}

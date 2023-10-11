// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../../src/TimelockedToken.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CrowdSale, Sale, SaleInfo } from "../../src/crowdsale/CrowdSale.sol";
import { CrowdSaleWithFees } from "../../src/crowdsale/CrowdSaleWithFees.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { Strings as SLib } from "../../src/helpers/Strings.sol";
import { IPToken } from "../../src/IPToken.sol";

import { CommonScript } from "./Common.sol";

/**
 * @title deploy crowdSale
 * @author
 */
contract DeployCrowdSale is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        CrowdSaleWithFees crowdSaleWithFees = new CrowdSaleWithFees(10);
        vm.stopBroadcast();

        console.log("CROWDSALE_WITH_FEES_ADDRESS=%s", address(crowdSaleWithFees));
    }
}

/**
 * @notice execute Ipnft.s.sol && Fixture.s.sol && Tokenizer.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1 and has synthesized it
 */
contract FixtureCrowdSale is CommonScript {
    FakeERC20 internal usdc;

    FakeERC20 daoToken;

    IPToken internal auctionToken;

    CrowdSaleWithFees crowdSaleWithFees;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal override {
        super.prepareAddresses();

        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));

        daoToken = FakeERC20(vm.envAddress("DAO_TOKEN_ADDRESS"));
        auctionToken = IPToken(vm.envAddress("IPTS_ADDRESS"));
        crowdSaleWithFees = CrowdSaleWithFees(vm.envAddress("CROWDSALE_WITH_FEES_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId, bytes memory permission) internal {
        vm.startBroadcast(bidder);
        usdc.approve(address(crowdSaleWithFees), amount);
        daoToken.approve(address(crowdSaleWithFees), amount);
        crowdSaleWithFees.placeBid(saleId, amount, permission);
        vm.stopBroadcast();
    }

    function run() public virtual {
        prepareAddresses();

        // Deal Charlie ERC20 tokens to bid in crowdsale
        dealERC20(alice, 1200 ether, usdc);
        dealERC20(charlie, 400 ether, usdc);

        // Deal Alice and Charlie DAO tokens to stake in crowdsale
        dealERC20(alice, 1200 ether, daoToken);
        dealERC20(charlie, 400 ether, daoToken);

        Sale memory _sale = Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20Metadata(address(usdc)),
            beneficiary: bob,
            fundingGoal: 200 ether,
            salesAmount: 400 ether,
            closingTime: uint64(block.timestamp + 15),
            permissioner: permissioner
        });

        vm.startBroadcast(bob);

        auctionToken.approve(address(crowdSaleWithFees), 400 ether);
        uint256 saleId = crowdSaleWithFees.startSale(_sale);
        vm.stopBroadcast();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(alice, 600 ether, saleId, abi.encodePacked(r, s, v));
        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(charlie, 200 ether, saleId, abi.encodePacked(r, s, v));
        console.log("SALE_ID=%s", saleId);
        vm.writeFile("SALEID.txt", Strings.toString(saleId));
    }
}

contract ClaimSale is CommonScript {
    function run() public {
        prepareAddresses();
        CrowdSaleWithFees crowdSaleWithFees = CrowdSaleWithFees(vm.envAddress("CROWDSALE_WITH_FEES_ADDRESS"));
        uint256 saleId = SLib.stringToUint(vm.readFile("SALEID.txt"));
        vm.removeFile("SALEID.txt");

        vm.startBroadcast(anyone);
        crowdSaleWithFees.settle(saleId);
        crowdSaleWithFees.claimResults(saleId);
        vm.stopBroadcast();
    }
}

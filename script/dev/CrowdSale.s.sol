// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../../src/TimelockedToken.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CrowdSale, Sale, SaleInfo } from "../../src/crowdsale/CrowdSale.sol";
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { Molecules } from "../../src/Molecules.sol";

import { CommonScript } from "./Common.sol";

/**
 * @title deploy crowdSale
 * @author
 */
contract DeployCrowdSale is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale();
        TokenVesting vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));
        vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        vm.stopBroadcast();

        //console.log("vested molecules Token %s", address(vestedMolToken));
        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
    }
}

/**
 * @notice execute Ipnft.s.sol && Fixture.s.sol && Synthesize.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1 and has synthesized it
 */
contract FixtureCrowdSale is CommonScript {
    FakeERC20 internal usdc;

    FakeERC20 daoToken;
    TokenVesting vestedDaoToken;

    Molecules internal auctionToken;

    StakedLockingCrowdSale stakedLockingCrowdSale;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal override {
        super.prepareAddresses();

        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));

        daoToken = FakeERC20(vm.envAddress("DAO_TOKEN_ADDRESS"));
        vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));

        stakedLockingCrowdSale = StakedLockingCrowdSale(vm.envAddress("STAKED_LOCKING_CROWDSALE_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function setupVestedMolToken() internal {
        vm.startBroadcast(deployer);
        auctionToken = Molecules(vm.envAddress("MOLECULES_ADDRESS"));

        vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        vm.stopBroadcast();
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId, bytes memory permission) internal {
        vm.startBroadcast(bidder);
        usdc.approve(address(stakedLockingCrowdSale), amount);
        daoToken.approve(address(stakedLockingCrowdSale), amount);
        stakedLockingCrowdSale.placeBid(saleId, amount, permission);
        vm.stopBroadcast();
    }

    function run() public virtual {
        prepareAddresses();

        setupVestedMolToken();

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
        auctionToken.approve(address(stakedLockingCrowdSale), 400 ether);
        uint256 saleId = stakedLockingCrowdSale.startSale(_sale, daoToken, vestedDaoToken, 1e18, 7 days);
        TimelockedToken lockedMolToken = stakedLockingCrowdSale.lockingContracts(address(auctionToken));
        vm.stopBroadcast();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(alice, 600 ether, saleId, abi.encodePacked(r, s, v));
        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(charlie, 200 ether, saleId, abi.encodePacked(r, s, v));
        console.log("LOCKED_MOLECULES_ADDRESS=%s", address(lockedMolToken));
        console.log("SALE_ID=%s", saleId);
    }
}

contract ClaimSale is CommonScript {
    function run() public {
        prepareAddresses();
        TermsAcceptedPermissioner permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
        StakedLockingCrowdSale stakedLockingCrowdSale = StakedLockingCrowdSale(vm.envAddress("STAKED_LOCKING_CROWDSALE_ADDRESS"));
        Molecules auctionToken = Molecules(vm.envAddress("MOLECULES_ADDRESS"));

        uint256 saleId = vm.envUint("SALE_ID");

        vm.startBroadcast(anyone);
        stakedLockingCrowdSale.settle(saleId);
        vm.stopBroadcast();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        vm.startBroadcast(alice);
        stakedLockingCrowdSale.claim(saleId, abi.encodePacked(r, s, v));
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        stakedLockingCrowdSale.claim(saleId, abi.encodePacked(r, s, v));
        vm.stopBroadcast();
    }
}

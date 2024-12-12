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
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { Strings as SLib } from "../../src/helpers/Strings.sol";
import { IPToken } from "../../src/IPToken.sol";

import { CommonScript } from "./Common.sol";

contract DeployCrowdSale is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        CrowdSale crowdSale = new CrowdSale();
        crowdSale.setCurrentFeesBp(1000);

        console.log("PLAIN_CROWDSALE_ADDRESS=%s", address(crowdSale));
    }
}

contract DeployStakedCrowdSale is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        TimelockedToken lockingCrowdsaleImplementation = new TimelockedToken();
        StakedLockingCrowdSale stakedLockingCrowdSale = new StakedLockingCrowdSale(lockingCrowdsaleImplementation);
        
        TokenVesting vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));
        vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedLockingCrowdSale));
        stakedLockingCrowdSale.trustVestingContract(vestedDaoToken);
        vm.stopBroadcast();

        console.log("STAKED_LOCKING_CROWDSALE_ADDRESS=%s", address(stakedLockingCrowdSale));
    }
}

contract FixtureCrowdSale is CommonScript {
    FakeERC20 internal usdc;

    FakeERC20 daoToken;

    IPToken internal auctionToken;

    CrowdSale crowdSale;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal virtual override {
        super.prepareAddresses();

        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));

        daoToken = FakeERC20(vm.envAddress("DAO_TOKEN_ADDRESS"));

        auctionToken = IPToken(vm.envAddress("IPTS_ADDRESS"));

        crowdSale = CrowdSale(vm.envAddress("PLAIN_CROWDSALE_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId, bytes memory permission) internal {
        vm.startBroadcast(bidder);
        usdc.approve(address(crowdSale), amount);
        daoToken.approve(address(crowdSale), amount);
        crowdSale.placeBid(saleId, amount, permission);
        vm.stopBroadcast();
    }

    function prepareRun() internal virtual returns (Sale memory _sale) {
        // Deal Charlie ERC20 tokens to bid in crowdsale
        dealERC20(alice, 1200 ether, usdc);
        dealERC20(charlie, 400 ether, usdc);

        _sale = Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20Metadata(address(usdc)),
            beneficiary: bob,
            fundingGoal: 200 ether,
            salesAmount: 400 ether,
            closingTime: uint64(block.timestamp + 10),
            permissioner: permissioner
        });

        vm.startBroadcast(bob);
        auctionToken.approve(address(crowdSale), 400 ether);
        vm.stopBroadcast();
    }

    function startSale() internal virtual returns (uint256 saleId) {
        Sale memory _sale = prepareRun();
        vm.startBroadcast(bob);
        saleId = crowdSale.startSale(_sale);
        vm.stopBroadcast();
    }

    function afterRun(uint256 saleId) internal virtual {
        console.log("SALE_ID=%s", saleId);
        vm.writeFile("SALEID.txt", Strings.toString(saleId));
    }

    function run() public virtual {
        prepareAddresses();

        uint256 saleId = startSale();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(alice, 600 ether, saleId, abi.encodePacked(r, s, v));
        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(charlie, 200 ether, saleId, abi.encodePacked(r, s, v));

        afterRun(saleId);
    }
}
/**
 * @notice execute Ipnft.s.sol && Fixture.s.sol && Tokenizer.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1 and has synthesized it
 */

contract FixtureStakedCrowdSale is FixtureCrowdSale {
    StakedLockingCrowdSale _slCrowdSale;
    TokenVesting vestedDaoToken;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));

        _slCrowdSale = StakedLockingCrowdSale(vm.envAddress("STAKED_LOCKING_CROWDSALE_ADDRESS"));
        crowdSale = _slCrowdSale;
    }

    function prepareRun() internal virtual override returns (Sale memory _sale) {
        _sale = super.prepareRun();
        dealERC20(alice, 1200 ether, daoToken);
        dealERC20(charlie, 400 ether, daoToken);
    }

    function startSale() internal override returns (uint256 saleId) {
        Sale memory _sale = prepareRun();
        vm.startBroadcast(bob);
        saleId = _slCrowdSale.startSale(_sale, daoToken, vestedDaoToken, 1e18, 7 days, 7 days);
        vm.stopBroadcast();
    }

    function afterRun(uint256 saleId) internal virtual override {
        super.afterRun(saleId);

        TimelockedToken lockedIpt = _slCrowdSale.lockingContracts(address(auctionToken));
        console.log("LOCKED_IPTS_ADDRESS=%s", address(lockedIpt));
    }
}

contract ClaimSale is CommonScript {
    function run() public {
        prepareAddresses();
        CrowdSale crowdSale = CrowdSale(vm.envAddress("CROWDSALE"));
        TermsAcceptedPermissioner permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));

        IPToken auctionToken = IPToken(vm.envAddress("IPTS_ADDRESS"));
        uint256 saleId = SLib.stringToUint(vm.readFile("SALEID.txt"));
        vm.removeFile("SALEID.txt");

        vm.startBroadcast(anyone);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        vm.stopBroadcast();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        vm.startBroadcast(alice);
        crowdSale.claim(saleId, abi.encodePacked(r, s, v));
        vm.stopBroadcast();

        //we don't let charlie claim so we can test upgrades
        // vm.startBroadcast(charlie);
        // (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        // stakedLockingCrowdSale.claim(saleId, abi.encodePacked(r, s, v));
        // vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { IPermissioner, BlindPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { FakeERC20, PermissionedERC20Token } from "../../src/helpers/FakeERC20.sol";
import { CommonScript } from "./Common.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";

import { TimelockedToken } from "../../src/TimelockedToken.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CrowdSale, Sale, SaleInfo } from "../../src/crowdsale/CrowdSale.sol";
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";
import { ITokenVesting, ROLE_CREATE_SCHEDULE } from "../../src/ITokenVesting.sol";
import { Strings as SLib } from "../../src/helpers/Strings.sol";

contract DeployFakeTokens is CommonScript {
    function run() public {
        super.prepareAddresses();
        vm.startBroadcast(deployer);
        FakeERC20 usdc = new FakeERC20("Usdc", "USDC");
        usdc.setDecimals(6);

        FakeERC20 daotoken = new FakeERC20("Bio DAO", "BDAO");
        vm.stopBroadcast();

        console.log("USDC_ADDRESS=%s", address(usdc));
        console.log("DAO_TOKEN_ADDRESS=%s", address(daotoken));
    }
}

contract DeployPermissionedToken is CommonScript {
    function run() public {
        super.prepareAddresses();
        vm.startBroadcast(deployer);
        PermissionedERC20Token t = new PermissionedERC20Token("IP Token", "IPT", "bafkrei");
        vm.stopBroadcast();

        console.log("IPTOKEN_ADDRESS=%s", address(t));
    }
}

contract DeployTokenVesting is CommonScript {
    function run() public {
        super.prepareAddresses();
        vm.startBroadcast(deployer);

        IERC20Metadata daoToken = IERC20Metadata(vm.envAddress("DAO_TOKEN_ADDRESS"));

        StakedLockingCrowdSale stakedLockingCrowdSale =
            StakedLockingCrowdSale(vm.envAddress("STAKED_LOCKING_CROWDSALE_ADDRESS"));

        ITokenVesting tokenVesting = ITokenVesting(
            address(
                new TokenVesting(
                    daoToken,
                    string(abi.encodePacked("Vested ", daoToken.name())),
                    string(abi.encodePacked("v", daoToken.symbol()))
                )
            )
        );

        tokenVesting.grantRole(ROLE_CREATE_SCHEDULE, address(stakedLockingCrowdSale));
        stakedLockingCrowdSale.trustVestingContract(tokenVesting);
        vm.stopBroadcast();
        console.log("TOKEN_VESTING_ADDRESS=%s", address(tokenVesting));
    }
}

contract FixtureCrowdSale is CommonScript {
    FakeERC20 internal usdc;
    FakeERC20 daoToken;
    FakeERC20 internal auctionToken;

    CrowdSale crowdSale;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal virtual override {
        super.prepareAddresses();

        auctionToken = FakeERC20(vm.envAddress("IPTOKEN_ADDRESS"));
        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));
        daoToken = FakeERC20(vm.envAddress("DAO_TOKEN_ADDRESS"));
        crowdSale = CrowdSale(vm.envAddress("PLAIN_CROWDSALE_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId, bytes memory permission) internal virtual {
        vm.startBroadcast(bidder);
        usdc.approve(address(crowdSale), amount);
        crowdSale.placeBid(saleId, amount, permission);
        vm.stopBroadcast();
    }

    function prepareRun() internal virtual returns (Sale memory _sale) {
        dealERC20(bob, 100_000 ether, auctionToken);
        dealERC20(alice, 50_000e6, usdc);
        dealERC20(charlie, 50_000e6, usdc);

        _sale = Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20Metadata(address(usdc)),
            beneficiary: bob,
            fundingGoal: 200e6,
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

        string memory terms = permissioner.specificTerms("bafkrei");

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, MessageHashUtils.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(alice, 600e6, saleId, abi.encodePacked(r, s, v));

        (v, r, s) = vm.sign(charliePk, MessageHashUtils.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(charlie, 200e6, saleId, abi.encodePacked(r, s, v));

        afterRun(saleId);
    }
}

contract FixtureStakedCrowdSale is FixtureCrowdSale {
    StakedLockingCrowdSale _slCrowdSale;
    ITokenVesting vestedDaoToken;

    function prepareAddresses() internal override {
        super.prepareAddresses();
        vestedDaoToken = ITokenVesting(vm.envAddress("TOKEN_VESTING_ADDRESS"));
        _slCrowdSale = StakedLockingCrowdSale(vm.envAddress("STAKED_LOCKING_CROWDSALE_ADDRESS"));
        crowdSale = _slCrowdSale;
    }

    function prepareRun() internal virtual override returns (Sale memory _sale) {
        _sale = super.prepareRun();
        dealERC20(alice, 50_000e6, usdc);
        dealERC20(charlie, 50_000e6, usdc);

        dealERC20(alice, 50_000e18, daoToken);
        dealERC20(charlie, 50_000e18, daoToken);
    }

    function startSale() internal override returns (uint256 saleId) {
        Sale memory _sale = prepareRun();
        vm.startBroadcast(bob);
        saleId = _slCrowdSale.startSale(_sale, daoToken, vestedDaoToken, 1e6, 7 days);
        vm.stopBroadcast();
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId, bytes memory permission) internal override {
        vm.startBroadcast(bidder);
        usdc.approve(address(crowdSale), amount);
        daoToken.approve(address(crowdSale), amount * 10e12);
        crowdSale.placeBid(saleId, amount, permission);
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
        TermsAcceptedPermissioner permissioner =
            TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));

        FakeERC20 auctionToken = FakeERC20(vm.envAddress("IPTOKEN_ADDRESS"));
        uint256 saleId = SLib.stringToUint(vm.readFile("SALEID.txt"));

        vm.startBroadcast(anyone);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        vm.stopBroadcast();

        string memory terms = permissioner.specificTerms("bafkrei");

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(alicePk, MessageHashUtils.toEthSignedMessageHash(abi.encodePacked(terms)));
        vm.startBroadcast(alice);
        crowdSale.claim(saleId, abi.encodePacked(r, s, v));
        vm.stopBroadcast();

        vm.removeFile("SALEID.txt");
        //we don't let charlie claim so we can test upgrades
        // vm.startBroadcast(charlie);
        // (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        // stakedLockingCrowdSale.claim(saleId, abi.encodePacked(r, s, v));
        // vm.stopBroadcast();
    }
}

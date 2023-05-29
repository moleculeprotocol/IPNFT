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

import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { CrowdSale, Sale, SaleInfo } from "../../src/crowdsale/CrowdSale.sol";
import { VestingConfig } from "../../src/crowdsale/VestedCrowdSale.sol";
import { StakedVestedCrowdSale } from "../../src/crowdsale/StakedVestedCrowdSale.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { FractionalizedToken } from "../../src/FractionalizedToken.sol";

import { CommonScript } from "./Common.sol";

/**
 * @title deploy crowdSale
 * @author
 */
contract DeployCrowdSale is CommonScript {
    function run() public {
        prepareAddresses();
        vm.startBroadcast(deployer);
        StakedVestedCrowdSale stakedVestedCrowdSale = new StakedVestedCrowdSale();
        TokenVesting vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));
        vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedVestedCrowdSale));
        vm.stopBroadcast();

        //console.log("vested fraction Token %s", address(vestedMolToken));
        console.log("STAKED_VESTED_CROWDSALE_ADDRESS=%s", address(stakedVestedCrowdSale));
    }
}

/**
 * @notice execute Ipnft.s.sol && Fixture.s.sol && Fractionalize.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1 and has fractionalized it
 */
contract FixtureCrowdSale is CommonScript {
    FakeERC20 internal usdc;

    FakeERC20 daoToken;
    TokenVesting vestedDaoToken;

    FractionalizedToken internal auctionToken;
    TokenVesting vestedMolToken;

    StakedVestedCrowdSale stakedVestedCrowdSale;
    TermsAcceptedPermissioner permissioner;

    function prepareAddresses() internal override {
        super.prepareAddresses();

        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));

        daoToken = FakeERC20(vm.envAddress("DAO_TOKEN_ADDRESS"));
        vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));

        stakedVestedCrowdSale = StakedVestedCrowdSale(vm.envAddress("STAKED_VESTED_CROWDSALE_ADDRESS"));
        permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
    }

    function setupVestedMolToken() internal {
        vm.startBroadcast(deployer);
        auctionToken = FractionalizedToken(vm.envAddress("FRACTIONALIZED_TOKEN_ADDRESS"));
        vestedMolToken = new TokenVesting(
            IERC20Metadata(address(auctionToken)),
            string(abi.encodePacked("Vested ", auctionToken.name())),
            string(abi.encodePacked("v", auctionToken.symbol()))
        );
        vestedMolToken.grantRole(vestedMolToken.ROLE_CREATE_SCHEDULE(), address(stakedVestedCrowdSale));
        console.log("VESTED_FRACTIONALIZED_TOKEN_ADDRESS=%s", address(vestedMolToken));

        vestedDaoToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedVestedCrowdSale));
        vm.stopBroadcast();
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId, bytes memory permission) internal {
        vm.startBroadcast(bidder);
        usdc.approve(address(stakedVestedCrowdSale), amount);
        daoToken.approve(address(stakedVestedCrowdSale), amount);
        stakedVestedCrowdSale.placeBid(saleId, amount, permission);
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
            closingTime: uint64(block.timestamp + 2 hours + 5 minutes),
            permissioner: permissioner
        });

        vm.startBroadcast(bob);
        auctionToken.approve(address(stakedVestedCrowdSale), 400 ether);
        uint256 saleId = stakedVestedCrowdSale.startSale(_sale, daoToken, vestedDaoToken, 1e18, vestedMolToken, 60 days);
        vm.stopBroadcast();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(alice, 600 ether, saleId, abi.encodePacked(r, s, v));
        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        placeBid(charlie, 200 ether, saleId, abi.encodePacked(r, s, v));
        console.log("SALE_ID=%s", saleId);
    }
}

contract OpenEmptySimpleWethCrowdSale is FixtureCrowdSale {
    function run() public override {
        prepareAddresses();

        setupVestedMolToken();
        vm.startBroadcast(deployer);
        FakeERC20 weth = new FakeERC20("wrapped Fakethereum", "WFETH");
        // weth.setDecimals(18);
        weth.mint(alice, 50 ether);
        weth.mint(charlie, 50 ether);
        vm.stopBroadcast();

        dealERC20(alice, 1_000_000 ether, daoToken);
        dealERC20(charlie, 1_000_000 ether, daoToken);
        // https://api.coingecko.com/api/v3/simple/price?ids=vitadao&vs_currencies=eth
        // 1 Vita = 0.00103384 ETH => VITA/ETH = 1 / 0.00103384
        uint256 wadFixedStakedPerBidPrice = 967.267662308 ether;

        Sale memory _sale = Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: IERC20Metadata(address(weth)),
            beneficiary: bob,
            fundingGoal: 20 ether,
            salesAmount: 400_000 ether,
            closingTime: uint64(block.timestamp + 2 hours + 5 minutes),
            permissioner: IPermissioner(address(0))
        });

        vm.startBroadcast(bob);
        auctionToken.approve(address(stakedVestedCrowdSale), 400_000 ether);

        uint256 saleId = stakedVestedCrowdSale.startSale(_sale, daoToken, vestedDaoToken, 1e18, vestedMolToken, 60 days);

        vm.stopBroadcast();

        console.log("WETH_ADDRESS=%s", address(weth));
        console.log("SALE_ID=%s", saleId);
    }
}

contract ClaimSale is CommonScript {
    function run() public {
        prepareAddresses();
        TermsAcceptedPermissioner permissioner = TermsAcceptedPermissioner(vm.envAddress("TERMS_ACCEPTED_PERMISSIONER_ADDRESS"));
        StakedVestedCrowdSale stakedVestedCrowdSale = StakedVestedCrowdSale(vm.envAddress("STAKED_VESTED_CROWDSALE_ADDRESS"));
        FractionalizedToken auctionToken = FractionalizedToken(vm.envAddress("FRACTIONALIZED_TOKEN_ADDRESS"));

        uint256 saleId = vm.envUint("SALE_ID");

        vm.startBroadcast(anyone);
        stakedVestedCrowdSale.settle(saleId);
        vm.stopBroadcast();

        string memory terms = permissioner.specificTermsV1(auctionToken);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        vm.startBroadcast(alice);
        stakedVestedCrowdSale.claim(saleId, abi.encodePacked(r, s, v));
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        (v, r, s) = vm.sign(charliePk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));
        stakedVestedCrowdSale.claim(saleId, abi.encodePacked(r, s, v));
        vm.stopBroadcast();
    }
}

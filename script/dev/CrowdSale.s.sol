// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { CrowdSale, Sale, SaleInfo } from "../../src/crowdsale/CrowdSale.sol";
import { VestingConfig } from "../../src/crowdsale/VestedCrowdSale.sol";
import { StakedVestedCrowdSale, StakingConfig } from "../../src/crowdsale/StakedVestedCrowdSale.sol";
import { FakeERC20 } from "../../test/helpers/FakeERC20.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";

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

    function prepareAddresses() internal override {
        super.prepareAddresses();
        usdc = FakeERC20(vm.envAddress("USDC_ADDRESS"));

        daoToken = FakeERC20(vm.envAddress("DAO_TOKEN_ADDRESS"));
        vestedDaoToken = TokenVesting(vm.envAddress("VDAO_TOKEN_ADDRESS"));

        stakedVestedCrowdSale = StakedVestedCrowdSale(vm.envAddress("STAKED_VESTED_CROWDSALE_ADDRESS"));
    }

    function setupVestedMolToken() internal {
        auctionToken = FractionalizedToken(vm.envAddress("FRACTIONALIZED_TOKEN_ADDRESS"));
        vestedMolToken = new TokenVesting(
            IERC20Metadata(address(auctionToken)),
            string(abi.encodePacked("Vested ", auctionToken.name())),
            string(abi.encodePacked("v", auctionToken.symbol()))
        );
        vestedMolToken.grantRole(vestedDaoToken.ROLE_CREATE_SCHEDULE(), address(stakedVestedCrowdSale));
        console.log("VESTED_FRACTIONALIZED_TOKEN_ADDRESS=%s", address(vestedMolToken));
    }

    function placeBid(address bidder, uint256 amount, uint256 saleId) internal {
        vm.startBroadcast(bidder);
        usdc.approve(address(stakedVestedCrowdSale), amount);
        daoToken.approve(address(stakedVestedCrowdSale), amount);
        stakedVestedCrowdSale.placeBid(saleId, amount);
        vm.stopBroadcast();
    }

    function run() public {
        prepareAddresses();

        // Deal Charlie ERC20 tokens to bid in crowdsale
        dealERC20(alice, 1200 ether, usdc);
        dealERC20(charlie, 400 ether, usdc);

        // Deal Alice and Charlie DAO tokens to stake in crowdsale
        dealERC20(alice, 1200 ether, daoToken);
        dealERC20(charlie, 400 ether, daoToken);

        Sale memory _sale = Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: FakeERC20(address(usdc)),
            beneficiary: bob,
            fundingGoal: 200 ether,
            salesAmount: 400 ether,
            closingTime: uint64(block.timestamp + 5 seconds)
        });

        VestingConfig memory _vestingConfig = VestingConfig({ vestingContract: vestedMolToken, cliff: 60 days });

        StakingConfig memory _stakingConfig =
            StakingConfig({ stakedToken: daoToken, stakesVestingContract: vestedDaoToken, wadFixedDaoPerBidPrice: 1e18, stakeTotal: 0 });

        vm.startBroadcast(bob);
        auctionToken.approve(address(stakedVestedCrowdSale), 400 ether);
        uint256 saleId = stakedVestedCrowdSale.startSale(_sale, _stakingConfig, _vestingConfig);
        vm.stopBroadcast();

        placeBid(alice, 600 ether, saleId);
        placeBid(charlie, 200 ether, saleId);
        console.log("SALE_ID=%s", saleId);

        //Create second CrowdSale that will not be settled
        Sale memory _sale2 = Sale({
            beneficiary: bob,
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: FakeERC20(address(usdc)),
            fundingGoal: 200 ether,
            salesAmount: 400 ether,
            closingTime: uint64(block.timestamp + 4 hours)
        });

        vm.startBroadcast(bob);
        auctionToken.approve(address(stakedVestedCrowdSale), 400 ether);
        uint256 saleId2 = stakedVestedCrowdSale.startSale(_sale2, _stakingConfig, _vestingConfig);
        vm.stopBroadcast();

        placeBid(alice, 600 ether, saleId2);
        placeBid(charlie, 200 ether, saleId2);
    }
}

contract ClaimSale is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        uint256 saleId = vm.envUint("SALE_ID");
        StakedVestedCrowdSale stakedVestedCrowdSale = StakedVestedCrowdSale(vm.envAddress("STAKED_VESTED_CROWDSALE_ADDRESS"));

        (address alice,) = deriveRememberKey(mnemonic, 2);
        (address charlie,) = deriveRememberKey(mnemonic, 3);
        (address anyone,) = deriveRememberKey(mnemonic, 4);

        vm.startBroadcast(anyone);
        stakedVestedCrowdSale.settle(saleId);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        stakedVestedCrowdSale.claim(saleId);
        vm.stopBroadcast();

        vm.startBroadcast(charlie);
        stakedVestedCrowdSale.claim(saleId);
        vm.stopBroadcast();
    }
}

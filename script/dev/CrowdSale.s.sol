// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo } from "../../src/crowdsale/CrowdSale.sol";
import { VestingConfig } from "../../src/crowdsale/VestedCrowdSale.sol";
import { StakedVestedCrowdSale, StakingConfig } from "../../src/crowdsale/StakedVestedCrowdSale.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { FakeERC20 } from "../../test/helpers/FakeERC20.sol";
import { FractionalizedToken } from "../../src/FractionalizedToken.sol";



/**
 * @title CrowdSale
 * @author
 * @notice execute Ipnft.s.sol && Fixture.s.sol && Fractionalize.s.sol first
 * @notice assumes that bob (hh1) owns IPNFT#1 and has fractionalized it
 */
contract CrowdSaleScript is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    address deployer;
    address bob;
    address alice;
    address charlie;
    address anyone;

    FractionalizedToken internal auctionToken;
    FakeERC20 internal erc20;

    function prepareAddresses() internal {
        (deployer,) = deriveRememberKey(mnemonic, 0);
        (bob,) = deriveRememberKey(mnemonic, 1);
        (alice,) = deriveRememberKey(mnemonic, 2);
        (charlie,) = deriveRememberKey(mnemonic, 3);
        (anyone,) = deriveRememberKey(mnemonic, 4);
    }


    function makeSale() internal returns (Sale memory sale) {
        return Sale({
            auctionToken: IERC20Metadata(address(auctionToken)),
            biddingToken: FakeERC20(address(erc20)),
            fundingGoal: 200 ether,
            salesAmount: 400 ether,
            closingTime: 0
        });
    }

    function bid(address bidder, uint256 amount, uint256 saleId, FakeERC20 daoToken, StakedVestedCrowdSale stakedVestedCrowdSale) internal {
        vm.startBroadcast(bidder);
        erc20.approve(address(stakedVestedCrowdSale), amount);
        daoToken.approve(address(stakedVestedCrowdSale), amount);
        stakedVestedCrowdSale.placeBid(saleId, amount);
        vm.stopBroadcast();
    }

    function claim(address claimer, uint256 saleId, StakedVestedCrowdSale stakedVestedCrowdSale) internal {
        vm.startBroadcast(claimer);
        stakedVestedCrowdSale.claim(saleId);
        vm.stopBroadcast();
    }

    function dealERC20(address to, uint256 amount, FakeERC20 token) internal {
        vm.startBroadcast(deployer);
        token.mint(to, amount);
        vm.stopBroadcast();
    }

    function run() public {
        prepareAddresses();

        auctionToken = FractionalizedToken(vm.envAddress("FRACTIONALIZED_TOKEN_ADDRESS"));
        erc20 = FakeERC20(vm.envAddress("ERC20_ADDRESS"));

        vm.startBroadcast(deployer);
        StakedVestedCrowdSale stakedVestedCrowdSale = new StakedVestedCrowdSale();
        FakeERC20 daoToken = new FakeERC20("DAO Token", "DAO");
        TokenVesting vestedDaoToken = new TokenVesting(IERC20Metadata(address(daoToken)), "VDAO Token", "VDAO");
        vm.stopBroadcast();

        // Deal Charlie ERC20 tokens to bid in crowdsale
        dealERC20(charlie, 1000 ether, erc20);

        // Deal Alice and Charlie DAO tokens to stake in crowdsale
        dealERC20(alice, 1000 ether, daoToken);
        dealERC20(charlie, 1000 ether, daoToken);

        vm.startBroadcast(bob);
        Sale memory _sale = makeSale();

        auctionToken.approve(address(stakedVestedCrowdSale), 400 ether);
        uint256 saleId = stakedVestedCrowdSale.startSale(_sale, daoToken, vestedDaoToken, 1e18, 60 days, 365 days);
        vm.stopBroadcast();

        bid(alice, 100 ether, saleId, daoToken, stakedVestedCrowdSale);
        bid(charlie, 100 ether, saleId, daoToken, stakedVestedCrowdSale);

        vm.startBroadcast(anyone);
        stakedVestedCrowdSale.settle(saleId);
        vm.stopBroadcast();

        claim(alice, saleId, stakedVestedCrowdSale);
        claim(charlie, saleId, stakedVestedCrowdSale);

        console.log("daoToken %s", address(daoToken));
        console.log("vestedDaoToken %s", address(vestedDaoToken));
        console.log("stakedVestedCrowdsale %s", address(stakedVestedCrowdSale));

    }
}

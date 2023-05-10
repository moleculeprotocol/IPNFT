// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";

import { FakeERC20 } from "./helpers/FakeERC20.sol";
import { BioPriceFeed, Meta } from "../src/BioPriceFeed.sol";

contract BioPriceFeedTest is Test {
    address signaller = makeAddr("signaller");
    address buyer = makeAddr("buyer");
    FakeERC20 internal baseToken;
    FakeERC20 internal quoteToken;
    BioPriceFeed internal priceFeed;

    address internal base;
    address internal quote;

    address anyone = makeAddr("anyone");

    function setUp() public {
        vm.startPrank(signaller);
        priceFeed = new BioPriceFeed();
        vm.stopPrank();
        baseToken = new FakeERC20("Base Token","BT");
        quoteToken = new FakeERC20("Quote token", "QT");
        base = address(baseToken);
        quote = address(quoteToken);
    }

    function testOnlySignaller() public {
        vm.expectRevert();
        priceFeed.signal(base, quote, 1.5 ether);
    }

    function testSignalPrice() public {
        vm.startPrank(signaller);
        priceFeed.signal(base, quote, 1e18);

        assertEq(priceFeed.getPrice(base, quote), 1e18);
        assertEq(priceFeed.getPrice(quote, base), 1e18);
        vm.stopPrank();
    }

    function testSignalFpPrice() public {
        vm.startPrank(signaller);
        priceFeed.signal(base, quote, 1.5 ether);

        assertEq(priceFeed.getPrice(base, quote), 1.5 ether);
        assertEq(priceFeed.getPrice(quote, base), 0.666666666666666666 ether);
        vm.stopPrank();
    }

    function testCalculation() public {
        vm.startPrank(signaller);
        priceFeed.signal(base, quote, 1.5 ether);
    }

    /// @notice USDC has 6 decimals
    function testUSDCDecimals() public {
        vm.startPrank(signaller);
        //ETH / USDC
        priceFeed.signal(base, quote, 1500 ether);
        priceFeed.setMetadata(base, quote, Meta(6, bytes32("USD/ETH")));

        uint256 ethPerUsdc = priceFeed.getPrice(quote, base);
        assertEq(ethPerUsdc, 0.000666666666666666 ether);

        uint256 usdcPerEth = priceFeed.getPrice(base, quote);
        assertEq(usdcPerEth, 1_500_000_000);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";
import { CrowdSale, Sale, SaleInfo } from "../src/crowdsale/CrowdSale.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
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

    function testSignalFloatingPrice() public {
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
    function testUSDC() public {
        vm.startPrank(signaller);
        quoteToken.setDecimals(6);
        //base: usd, quote: eth usdc/eth
        priceFeed.signal(base, quote, 1500 ether);

        uint256 ethPerUsdc = priceFeed.getPrice(quote, base);
        assertEq(ethPerUsdc, 666666666666666);
        assertEq(ethPerUsdc, 0.000666666666666666 ether);

        uint256 usdcPerEth = priceFeed.getPrice(base, quote);
        assertEq(usdcPerEth, 1500 ether);

        //good, how much usdc do I get for 10 ETH?
        uint256 decimalAdjustedPrice = (FP.divWadDown(FP.mulWadDown(usdcPerEth, 10 ** quoteToken.decimals()), 10 ** baseToken.decimals()));
        uint256 usdcForTenEth = 10 * decimalAdjustedPrice;
        assertEq(usdcForTenEth, 15_000e6);

        //great, and how much do I get for 0.01 ETH
        uint256 usdcFor005Eth = FP.mulWadDown(0.01 ether, decimalAdjustedPrice);
        assertEq(usdcFor005Eth, 15e6);

        //finally, how much real USDC do I get for 1 ETH
        uint256 usdcFor1Eth = FP.mulWadDown(1 ether, decimalAdjustedPrice);
        assertEq(usdcFor1Eth, 1500e6);

        //turn it around. How much ether do I get for 1500 USDC?
        decimalAdjustedPrice = (FP.divWadUp(FP.mulWadUp(ethPerUsdc, 10 ** baseToken.decimals()), 10 ** quoteToken.decimals()));
        uint256 ethFor1500USDC = FP.mulWadDown(1500e6, decimalAdjustedPrice);
        assertEq(ethFor1500USDC, 0.999999999999999 ether);

        //great. And for 1.5 USDC?
        uint256 ethFor1USDC = FP.mulWadDown(15e5, decimalAdjustedPrice);
        assertEq(ethFor1USDC, 0.000999999999999999 ether);
    }

    function testGetPriceForNonExistentPair() public {
        address b = makeAddr("b");
        address q = makeAddr("q");
        // Should return price of 0 for pairs without existing signals
        assertEq(priceFeed.getPrice(b, q), 0);
    }
}

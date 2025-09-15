// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Metadata } from "../src/IIPToken.sol";
import { IPToken } from "../src/IPToken.sol";
import { CrowdSale, Sale, SaleInfo, SaleState, BadDecimals } from "../src/crowdsale/CrowdSale.sol";
import { StakedLockingCrowdSale, BadPrice } from "../src/crowdsale/StakedLockingCrowdSale.sol";
import { IPermissioner, TermsAcceptedPermissioner, InvalidSignature, BlindPermissioner } from "../src/Permissioner.sol";
import { MustControlIpnft, AlreadyTokenized, Tokenizer, ZeroAddress } from "../src/Tokenizer.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { TimelockedToken } from "../src/TimelockedToken.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
//import { BioPriceFeed, IPriceFeedConsumer } from "../src/BioPriceFeed.sol";
import { CrowdSaleHelpers } from "./helpers/CrowdSaleHelpers.sol";
import { AcceptAllAuthorizer } from "./helpers/AcceptAllAuthorizer.sol";

contract CrowdSalePermissionedTest is Test {
    address deployer = makeAddr("chucknorris");
    address emitter = makeAddr("emitter");
    address anyone = makeAddr("anyone");
    address bidder;
    uint256 bidderPk;

    IPToken internal auctionToken;
    FakeERC20 internal biddingToken;
    FakeERC20 internal daoToken;

    //this typically is the DAO's general vesting contract
    TokenVesting internal vestedDao;

    TermsAcceptedPermissioner internal permissioner;
    //BioPriceFeed internal priceFeed;

    StakedLockingCrowdSale internal crowdSale;

    uint256 MINTING_FEE = 0.001 ether;
    string agreementCid = "bafkrei";

    function setUp() public {
        (bidder, bidderPk) = makeAddrAndKey("bidder");

        vm.startPrank(deployer);
        IPNFT ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();
        ipnft.setAuthorizer(new AcceptAllAuthorizer());

        Tokenizer tokenizer = Tokenizer(
            address(
                new ERC1967Proxy(
                    address(new Tokenizer()),
                    abi.encodeWithSelector(Tokenizer.initialize.selector, [address(ipnft), address(new BlindPermissioner())])
                )
            )
        );

        tokenizer.setIPTokenImplementation(new IPToken());

        biddingToken = new FakeERC20("USD token", "USDC");
        daoToken = new FakeERC20("DAO token", "DAO");

        TimelockedToken timelockedTokenImplementation = new TimelockedToken();
        crowdSale = new StakedLockingCrowdSale(timelockedTokenImplementation);

        vestedDao = new TokenVesting(daoToken, string(abi.encodePacked("Vested ", daoToken.name())), string(abi.encodePacked("v", daoToken.symbol())));
        vestedDao.grantRole(vestedDao.ROLE_CREATE_SCHEDULE(), address(crowdSale));
        crowdSale.trustVestingContract(vestedDao);
        vm.stopPrank();

        vm.startPrank(emitter);
        vm.deal(emitter, MINTING_FEE);
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation{ value: MINTING_FEE }(emitter, reservationId, "", "", "");

        auctionToken = tokenizer.tokenizeIpnft(1, 100_000, "IPT", agreementCid, "");
        auctionToken.issue(emitter, 500_000 ether);

        vm.stopPrank();

        // here's a funny hack we're utilizing only for this test:
        // to make the tokenization easier, we're using a BlindPermissioner above
        // from now on, we're switching to a TermsAcceptedPermissioner
        permissioner = new TermsAcceptedPermissioner();
        vm.store(address(tokenizer), bytes32(uint256(3)), bytes32(uint256(uint160(address(permissioner)))));

        vm.startPrank(bidder);
        biddingToken.mint(bidder, 1_000_000 ether);
        daoToken.mint(bidder, 1_000_000 ether);
        biddingToken.approve(address(crowdSale), 1_000_000 ether);
        daoToken.approve(address(crowdSale), 1_000_000 ether);
        vm.stopPrank();
    }

    function testPermissionedSettlementAndSimpleClaims() public {
        vm.startPrank(emitter);
        Sale memory _sale = CrowdSaleHelpers.makeSale(emitter, IERC20Metadata(address(auctionToken)), biddingToken);
        _sale.permissioner = permissioner;
        auctionToken.approve(address(crowdSale), 400_000 ether);

        uint256 saleId = crowdSale.startSale(_sale, daoToken, vestedDao, 1e18, 60 days, 60 days);
        vm.stopPrank();

        string memory terms = permissioner.specificTermsV1(auctionToken);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bidderPk, ECDSA.toEthSignedMessageHash(abi.encodePacked(terms)));

        bytes memory xsignature = abi.encodePacked(r, s, v);

        vm.startPrank(bidder);
        vm.expectRevert(InvalidSignature.selector);
        crowdSale.placeBid(saleId, 200_000 ether, "");

        crowdSale.placeBid(saleId, 200_000 ether, xsignature);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(bidder), 800_000 ether);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(biddingToken.balanceOf(address(crowdSale)), 200_000 ether);
        assertEq(daoToken.balanceOf(address(crowdSale)), 200_000 ether);

        vm.startPrank(anyone);
        vm.warp(block.timestamp + 3 hours);
        crowdSale.settle(saleId);
        crowdSale.claimResults(saleId);
        vm.stopPrank();

        assertEq(biddingToken.balanceOf(emitter), _sale.fundingGoal);

        vm.startPrank(bidder);
        vm.expectRevert(InvalidSignature.selector);
        crowdSale.claim(saleId, "");

        crowdSale.claim(saleId, xsignature);
        vm.stopPrank();

        TimelockedToken auctionTokenVesting = crowdSale.lockingContracts(address(auctionToken));

        assertEq(auctionTokenVesting.balanceOf(bidder), _sale.salesAmount);
        assertEq(daoToken.balanceOf(bidder), 800_000 ether);
        assertEq(vestedDao.balanceOf(bidder), 200_000 ether);
    }
}

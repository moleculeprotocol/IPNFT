// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//prbmath only works with solidity > 0819
//https://github.com/paulrberg/prb-math
import { UD60x18, ud, convert } from "@prb/math/UD60x18.sol";

import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

struct Sale {
    IERC20 auctionToken;
    IERC20 biddingToken;
    //how many dollars to collect
    uint256 fundingGoal;
    //how many fractions to sell
    uint256 salesAmount;
    //$auction/$bidding
    uint256 fixedPrice;
}
// uint256 openingTime;
// uint256 closingTime;

struct SaleInfo {
    address beneficiary;
    bool settled;
    uint256 total;
    uint256 surplus;
}

contract CrowdSale {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _saleCounter;

    mapping(uint256 => Sale) _sales;
    mapping(uint256 => SaleInfo) _saleInfo;

    mapping(uint256 => mapping(address => uint256)) _contributions;

    event SaleStarted(Sale sale, address indexed emitter);

    constructor() {
        _saleCounter.increment(); //start at 1
    }

    function startSale(Sale memory sale) external returns (uint256 saleId) {
        if (sale.auctionToken.balanceOf(msg.sender) < sale.salesAmount) {
            revert("you dont have sufficient auction tokens");
        }
        saleId = _saleCounter.current();
        _sales[saleId] = sale;
        _saleInfo[saleId] = SaleInfo(msg.sender, false, 0, 0);
        _saleCounter.increment();

        sale.auctionToken.safeTransferFrom(msg.sender, address(this), sale.salesAmount);
        emit SaleStarted(sale, msg.sender);
    }

    function placeBid(uint256 saleId, uint256 biddingTokenAmount) external {
        Sale memory sale = _sales[saleId];
        IERC20 biddingToken = sale.biddingToken;
        _saleInfo[saleId].total += biddingTokenAmount;
        _contributions[saleId][msg.sender] += biddingTokenAmount;
        biddingToken.safeTransferFrom(msg.sender, address(this), biddingTokenAmount);
    }

    function settle(uint256 saleId) external {
        //todo anyone can call this for the beneficiary
        //todo time
        //todo check wether goal has been met
        _saleInfo[saleId].settled = true;
        _saleInfo[saleId].surplus = _saleInfo[saleId].total - _sales[saleId].fundingGoal;

        //transfer funds to issuer / beneficiary
        _sales[saleId].biddingToken.safeTransfer(_saleInfo[saleId].beneficiary, _sales[saleId].fundingGoal);
    }

    function claim(uint256 saleId) external {
        UD60x18 contribution = ud(_contributions[saleId][msg.sender]);
        UD60x18 fundingGoal = ud(_sales[saleId].fundingGoal);
        UD60x18 total = ud(_saleInfo[saleId].total);
        UD60x18 salesAmount = ud(_sales[saleId].salesAmount);

        UD60x18 biddingShare = (contribution * fundingGoal) / total;
        //        console.log(biddingShare);

        UD60x18 biddingRatio = biddingShare / fundingGoal;
        //console.log(biddingRatio);

        UD60x18 auctionTokens = biddingRatio * salesAmount;
        //       console.log(auctionTokens);

        if (_saleInfo[saleId].surplus > 0) {
            UD60x18 refunds = biddingRatio * ud(_saleInfo[saleId].surplus); //_contributions[saleId][msg.sender] - biddingShare;
            // console.log(refunds);

            if (!refunds.isZero()) {
                _sales[saleId].biddingToken.safeTransfer(msg.sender, refunds.unwrap());
            }
        }
        _sales[saleId].auctionToken.safeTransfer(msg.sender, auctionTokens.unwrap());
    }

    function saleInfo(uint256 saleId) public view returns (SaleInfo memory) {
        return _saleInfo[saleId];
    }

    function contribution(uint256 saleId, address contributor) public view returns (uint256) {
        return _contributions[saleId][contributor];
    }
}

/*
        if (_saleInfo[saleId].beneficiary != msg.sender) {
            revert("only emitter can claim the funds");
        }
        */
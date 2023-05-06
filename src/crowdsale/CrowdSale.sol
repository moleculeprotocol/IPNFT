// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    uint256 openingTime;
    uint256 closingTime;
}

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

    function startSale(Sale memory sale) external {
        _sales[_saleCounter.current()] = sale;
        _saleInfo[_saleCounter.current()] = SaleInfo(msg.sender, false, 0, 0);
        _saleCounter.increment();

        sale.auctionToken.safeTransferFrom(msg.sender, address(this), sale.fundingGoal);
        emit SaleStarted(sale, msg.sender);
    }

    function placeBid(uint256 saleId, uint256 biddingTokenAmount) external {
        Sale memory sale = _sales[saleId];
        IERC20 biddingToken = sale.biddingToken;
        _saleInfo[saleId].total += biddingTokenAmount;
        _contributions[saleId][msg.sender] += biddingTokenAmount;
        biddingToken.safeTransferFrom(msg.sender, address(this), biddingTokenAmount);
    }

    function settleSale(uint256 saleId) external {
        //todo anyone can call this for the beneficiary
        //todo time
        //todo check wether goal has been met
        _saleInfo[saleId].settled = true;
        _saleInfo[saleId].surplus = _saleInfo[saleId].total - _sales[saleId].fundingGoal;

        //transfer funds to issuer / beneficiary
        _sales[saleId].biddingToken.safeTransfer(_saleInfo[saleId].beneficiary, _sales[saleId].salesAmount);
    }

    function claim(uint256 saleId) external {
        uint256 biddingShare = (_contributions[saleId][msg.sender] * _sales[saleId].fundingGoal) / _saleInfo[saleId].total;

        uint256 auctionTokens = biddingShare * _sales[saleId].fixedPrice;
        uint256 refunds = _contributions[saleId][msg.sender] - biddingShare;

        _sales[saleId].auctionToken.safeTransfer(msg.sender, auctionTokens);
        _sales[saleId].biddingToken.safeTransfer(msg.sender, refunds);
    }
}

/*
        if (_saleInfo[saleId].beneficiary != msg.sender) {
            revert("only emitter can claim the funds");
        }
        */

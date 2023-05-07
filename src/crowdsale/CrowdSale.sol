// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";

import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

struct Sale {
    IERC20 auctionToken;
    IERC20 biddingToken;
    //how many bidding tokens to collect
    uint256 fundingGoal;
    //how many auction tokens to sell
    uint256 salesAmount;
    // uint256 openingTime;
    uint256 closingTime;
}

struct SaleInfo {
    address beneficiary;
    bool settled;
    uint256 total;
    uint256 surplus;
}

contract CrowdSale {
    using SafeERC20 for IERC20;

    mapping(uint256 => Sale) _sales;
    mapping(uint256 => SaleInfo) _saleInfo;

    mapping(uint256 => mapping(address => uint256)) _contributions;

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale);
    event Settled(uint256 indexed saleId, uint256 totalBids, uint256 surplus);
    event Claimed(uint256 indexed saleId, address indexed claimer, uint256 claimed, uint256 refunded);

    constructor() { }

    function startSale(Sale memory sale) public returns (uint256 saleId) {
        if (sale.auctionToken.balanceOf(msg.sender) < sale.salesAmount) {
            revert("you dont have sufficient auction tokens");
        }
        //close to 0 cases lead to very confusing results
        // if (sale.fundingGoal <= 0.5 ether || sale.salesAmount < 0.5 ether) {
        //     revert("you must sell or accept something meaningful");
        // }

        saleId = uint256(keccak256(abi.encode(sale)));
        _sales[saleId] = sale;
        _saleInfo[saleId] = SaleInfo(msg.sender, false, 0, 0);

        sale.auctionToken.safeTransferFrom(msg.sender, address(this), sale.salesAmount);
        emit Started(saleId, msg.sender, sale);
    }

    function placeBid(uint256 saleId, uint256 biddingTokenAmount) external {
        if (biddingTokenAmount == 0) {
            revert("must bid something");
        }

        Sale memory sale = _sales[saleId];
        if (sale.fundingGoal == 0) {
            revert("bad sale id");
        }

        IERC20 biddingToken = sale.biddingToken;
        _saleInfo[saleId].total += biddingTokenAmount;
        _contributions[saleId][msg.sender] += biddingTokenAmount;
        biddingToken.safeTransferFrom(msg.sender, address(this), biddingTokenAmount);
    }

    function settle(uint256 saleId) external {
        //todo anyone can call this for the beneficiary
        Sale memory sale = _sales[saleId];
        SaleInfo storage __saleInfo = _saleInfo[saleId];
        if (__saleInfo.total < sale.fundingGoal) {
            revert("funding goal not met");
        }
        if (__saleInfo.settled) {
            revert("sale is already settled");
        }
        //todo don't allow settlement before end time

        __saleInfo.settled = true;
        __saleInfo.surplus = __saleInfo.total - sale.fundingGoal;

        emit Settled(saleId, __saleInfo.total, __saleInfo.surplus);

        //transfer funds to issuer / beneficiary
        release(sale.biddingToken, __saleInfo.beneficiary, sale.fundingGoal);
    }

    function claim(uint256 saleId) external virtual {
        (uint256 auctionTokens, uint256 refunds) = getClaimableAmounts(saleId, msg.sender);
        emit Claimed(saleId, msg.sender, auctionTokens, refunds);

        if (refunds > 0) {
            _sales[saleId].biddingToken.safeTransfer(msg.sender, refunds);
        }
        _sales[saleId].auctionToken.safeTransfer(msg.sender, auctionTokens);
    }

    function saleInfo(uint256 saleId) public view returns (SaleInfo memory) {
        return _saleInfo[saleId];
    }

    function contribution(uint256 saleId, address contributor) public view returns (uint256) {
        return _contributions[saleId][contributor];
    }

    function release(IERC20 biddingToken, address beneficiary, uint256 fundingGoal) internal virtual {
        biddingToken.safeTransfer(beneficiary, fundingGoal);
    }

    function getClaimableAmounts(uint256 saleId, address bidder) internal view virtual returns (uint256 auctionTokens, uint256 refunds) {
        uint256 _contribution = _contributions[saleId][bidder];
        uint256 fundingGoal = _sales[saleId].fundingGoal;
        uint256 total = _saleInfo[saleId].total;
        uint256 salesAmount = _sales[saleId].salesAmount;

        uint256 biddingShare = FP.divWadDown(FP.mulWadDown(_contribution, fundingGoal), total);
        uint256 biddingRatio = FP.divWadDown(biddingShare, fundingGoal);
        auctionTokens = FP.mulWadDown(biddingRatio, salesAmount);
        if (_saleInfo[saleId].surplus > 0) {
            refunds = FP.mulWadDown(biddingRatio, _saleInfo[saleId].surplus); //_contributions[saleId][msg.sender] - biddingShare;
        } else {
            refunds = 0;
        }
    }
}

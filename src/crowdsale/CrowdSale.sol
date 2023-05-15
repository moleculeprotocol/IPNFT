// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";

import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

struct Sale {
    IERC20Metadata auctionToken;
    IERC20 biddingToken;
    address beneficiary;
    //how many bidding tokens to collect
    uint256 fundingGoal;
    //how many auction tokens to sell
    uint256 salesAmount;
    // uint256 openingTime;
    uint256 closingTime;
}

struct SaleInfo {
    bool settled;
    uint256 total;
    uint256 surplus;
}

error BalanceTooLow();
error BadDecimals();
error BadSaleDuration();
error SaleAlreadyActive();

contract CrowdSale {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;

    mapping(uint256 => Sale) _sales;
    mapping(uint256 => SaleInfo) _saleInfo;

    mapping(uint256 => mapping(address => uint256)) _contributions;

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale);
    event Settled(uint256 indexed saleId, uint256 totalBids, uint256 surplus);
    event Claimed(uint256 indexed saleId, address indexed claimer, uint256 claimed, uint256 refunded);
    event Bid(uint256 indexed saleId, address indexed bidder, uint256 amount);

    constructor() { }

    function startSale(Sale memory sale) public returns (uint256 saleId) {
        if (sale.closingTime < block.timestamp + 1 hours) {
            revert BadSaleDuration();
        }
        if (sale.auctionToken.decimals() != 18 || IERC20Metadata(address(sale.biddingToken)).decimals() != 18) {
            revert BadDecimals();
        }
        if (sale.auctionToken.balanceOf(msg.sender) < sale.salesAmount) {
            revert BalanceTooLow();
        }
        //close to 0 cases lead to very confusing results
        // if (sale.fundingGoal <= 0.5 ether || sale.salesAmount < 0.5 ether) {
        //     revert("you must sell or accept something meaningful");
        // }

        saleId = uint256(keccak256(abi.encode(sale)));
        if (address(_sales[saleId].auctionToken) != address(0)) {
            revert SaleAlreadyActive();
        }
        _sales[saleId] = sale;
        _saleInfo[saleId] = SaleInfo(false, 0, 0);

        sale.auctionToken.safeTransferFrom(msg.sender, address(this), sale.salesAmount);
        _onSaleStarted(saleId);
    }

    function _onSaleStarted(uint256 saleId) internal virtual {
        emit Started(saleId, msg.sender, _sales[saleId]);
    }

    function placeBid(uint256 saleId, uint256 biddingTokenAmount) public virtual {
        if (biddingTokenAmount == 0) {
            revert("must bid something");
        }

        Sale memory sale = _sales[saleId];
        if (sale.fundingGoal == 0) {
            revert("bad sale id");
        }

        if (_saleInfo[saleId].settled) {
            revert("sale is already settled");
        }

        IERC20 biddingToken = sale.biddingToken;
        _saleInfo[saleId].total += biddingTokenAmount;
        _contributions[saleId][msg.sender] += biddingTokenAmount;
        emit Bid(saleId, msg.sender, biddingTokenAmount);
        biddingToken.safeTransferFrom(msg.sender, address(this), biddingTokenAmount);
    }

    function settle(uint256 saleId) public virtual {
        Sale memory sale = _sales[saleId];
        SaleInfo storage __saleInfo = _saleInfo[saleId];
        //todo anyone can call this for the beneficiary

        //todo don't allow settlement before end time

        //todo: allow fundraiser to settle and allow everyone to withdraw if funding goal has *not* been met
        if (__saleInfo.total < sale.fundingGoal) {
            revert("funding goal not met");
        }
        if (__saleInfo.settled) {
            revert("sale is already settled");
        }

        __saleInfo.settled = true;
        __saleInfo.surplus = __saleInfo.total - sale.fundingGoal;

        emit Settled(saleId, __saleInfo.total, __saleInfo.surplus);

        //transfer funds to issuer / beneficiary
        release(sale.biddingToken, sale.beneficiary, sale.fundingGoal);
    }

    function claim(uint256 saleId) public virtual returns (uint256 auctionTokens, uint256 refunds) {
        (auctionTokens, refunds) = getClaimableAmounts(saleId, msg.sender);
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

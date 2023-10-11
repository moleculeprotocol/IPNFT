// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CrowdSale, Sale, SaleInfo, AlreadyClaimed, SaleState, BadSaleState } from "./CrowdSale.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CrowdSaleWithFees
 * @author molecule.to
 * @notice a plain crowdsale that takes 0.5% fees of the funding goal upon sale settlement
 */
contract CrowdSaleWithFees is CrowdSale, Ownable {
    using SafeERC20 for IERC20Metadata;

    mapping(uint256 => uint256) crowdSaleFees;
    uint256 public feesPercentage;

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale, uint256 feesPercentage);
    /**
     * is called when we deploy this smart contract,
     * we need to instantiate the initialFees percentage and the contract owner to send the fees to at the end of each successful auction
     * @param _feesPercentage the percentage of fees to cut of each auction
     */

    constructor(uint256 _feesPercentage) {
        feesPercentage = _feesPercentage;
    }

    function getFees() public view returns (uint256) {
        return feesPercentage;
    }

    function getCrowdSaleFees(uint256 saleId) public view returns (uint256) {
        return crowdSaleFees[saleId];
    }

    function updateCrowdSaleFees(uint256 newFee) public onlyOwner {
        feesPercentage = newFee;
    }

    /**
     * @notice will instantiate a new crowdsale with fees when none exists yet
     *
     * @param sale sale configuration
     * @return saleId the newly created sale's id
     */
    function startSale(Sale calldata sale) public override returns (uint256 saleId) {
        saleId = super.startSale(sale);
        crowdSaleFees[saleId] = feesPercentage;
    }

    function _afterSaleStarted(uint256 saleId) internal override {
        emit Started(saleId, msg.sender, _sales[saleId], crowdSaleFees[saleId]);
    }

    function settle(uint256 saleId) public override {
        Sale storage sale = _sales[saleId];
        super.settle(saleId);
        uint256 saleFees = sale.fundingGoal * feesPercentage / 1000;
        sale.fundingGoal = sale.fundingGoal - saleFees;
        sale.biddingToken.safeTransfer(owner(), saleFees);
    }
}

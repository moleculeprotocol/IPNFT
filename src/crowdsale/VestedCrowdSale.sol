// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";

import { CrowdSale, Sale, SaleState } from "./CrowdSale.sol";
import { InitializeableTokenVesting } from "./InitializableTokenVesting.sol";

struct VestingConfig {
    TokenVesting vestingContract;
    uint256 cliff;
    uint256 duration;
}

error ApprovalFailed();

/**
 * @title VestedCrowdSale
 *
 * @author molecule.to
 * @notice puts the sold tokens under a configured vesting scheme
 */
contract VestedCrowdSale is CrowdSale {
    using SafeERC20 for IERC20;

    mapping(uint256 => VestingConfig) public salesVesting;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    //address immutable tokenImplementation;

    // constructor() {
    //     tokenImplementation = address(new InitializeableTokenVesting(IERC20Metadata(address(new FakeIERC20())), "",""));
    // }

    event Started(uint256 saleId, address indexed issuer, Sale sale, VestingConfig vesting);

    function startSale(Sale memory sale, VestingConfig memory vesting) public returns (uint256 saleId) {
        saleId = uint256(keccak256(abi.encode(sale)));
        salesVesting[saleId] = vesting;
        saleId = super.startSale(sale);
    }

    function startSale(Sale memory sale, uint256 cliff, uint256 duration) public returns (uint256 saleId) {
        //todo: clone a new TokenVesting ERC20 contract and call start sale with that one
        //InitializeableTokenVesting vestingContract = InitializeableTokenVesting(Clones.clone(tokenImplementation));
        //vestingContract.initialize(sale.auctionToken);

        TokenVesting vestingContract = new TokenVesting(
            sale.auctionToken,
            string(abi.encodePacked("Vested ", sale.auctionToken.name())),
            string(abi.encodePacked("v", sale.auctionToken.symbol()))
        );
        VestingConfig memory vesting = VestingConfig(vestingContract, cliff, duration);
        return startSale(sale, vesting);
    }

    function _onSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId]);
    }

    function settle(uint256 saleId) public virtual override {
        super.settle(saleId);
        if (_saleInfo[saleId].state == SaleState.FAILED) {
            return;
        }

        Sale memory sale = _sales[saleId];
        VestingConfig memory vesting = salesVesting[saleId];
        bool result = sale.auctionToken.approve(address(vesting.vestingContract), sale.salesAmount);
        if (!result) {
            revert ApprovalFailed();
        }
    }

    function claim(uint256 saleId, uint256 auctionTokens, uint256 refunds) internal virtual override {
        emit Claimed(saleId, msg.sender, auctionTokens, refunds);

        VestingConfig memory vesting = salesVesting[saleId];
        if (refunds > 0) {
            _sales[saleId].biddingToken.safeTransfer(msg.sender, refunds);
        }

        IERC20(_sales[saleId].auctionToken).safeTransfer(address(vesting.vestingContract), auctionTokens);

        //todo: find out from where we want to count the vesting cliff time: opening time, settlement time or claiming time
        vesting.vestingContract.createVestingSchedule(
            msg.sender, _sales[saleId].openingTime, vesting.cliff, vesting.duration, 60, false, auctionTokens
        );
    }
}

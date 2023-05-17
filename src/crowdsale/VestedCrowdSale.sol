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
    event VestingContractCreated(TokenVesting vestingContract, IERC20 indexed underlyingToken);

    /**
     * @notice if vestingConfig.vestingContract is 0x0, a new vesting contract is automatically created
     *
     * @param sale  sale configuration
     * @param vestingConfig  vesting configuration
     */
    function startSale(Sale memory sale, VestingConfig memory vestingConfig) public returns (uint256 saleId) {
        saleId = uint256(keccak256(abi.encode(sale)));

        if (address(vestingConfig.vestingContract) == address(0)) {
            vestingConfig.vestingContract = _makeVestingContract(sale);
        }

        salesVesting[saleId] = vestingConfig;
        saleId = super.startSale(sale);
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

    /**
     * @dev will send auction tokens to the configured vesting contract. Only the cliff is configured.
     *
     * @param saleId sale id
     * @param tokenAmount amount of tokens to vest
     * @param refunds unvested tokens to be returned
     */
    function claim(uint256 saleId, uint256 tokenAmount, uint256 refunds) internal virtual override {
        VestingConfig memory vesting = salesVesting[saleId];
        if (refunds > 0) {
            _sales[saleId].biddingToken.safeTransfer(msg.sender, refunds);
        }

        emit Claimed(saleId, msg.sender, tokenAmount, refunds);
        IERC20(_sales[saleId].auctionToken).safeTransfer(address(vesting.vestingContract), tokenAmount);

        //the vesting start time is the official auction closing time
        //https://discord.com/channels/608198475598790656/1021413298756923462/1107442747687829515
        vesting.vestingContract.createVestingSchedule(msg.sender, _sales[saleId].closingTime, vesting.cliff, vesting.cliff, 60, false, tokenAmount);
    }

    function _makeVestingContract(Sale memory sale) private returns (TokenVesting vestingContract) {
        //todo: clone a new TokenVesting ERC20 contract and call start sale with that one
        //InitializeableTokenVesting vestingContract = InitializeableTokenVesting(Clones.clone(tokenImplementation));
        //vestingContract.initialize(sale.auctionToken);
        vestingContract = new TokenVesting(
            sale.auctionToken,
            string(abi.encodePacked("Vested ", sale.auctionToken.name())),
            string(abi.encodePacked("v", sale.auctionToken.symbol()))
        );
        emit VestingContractCreated(vestingContract, sale.auctionToken);
    }
}

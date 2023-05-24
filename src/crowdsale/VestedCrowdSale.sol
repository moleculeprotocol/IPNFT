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
    // a duration in seconds, will be counted from when the sale's closing time
    uint256 cliff;
}

error ApprovalFailed();
error UnmanageableVestingContract();
error InvalidDuration();
error IncompatibleVestingContract();

/**
 * @title VestedCrowdSale
 * @author molecule.to
 * @notice a fixed price sales base contract that locks the sold tokens in a configured vesting scheme
 */
contract VestedCrowdSale is CrowdSale {
    using SafeERC20 for IERC20Metadata;

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
     * @param vestingConfig  vesting configuration. Duration must be compatible to TokenVesting hard requirements (7 days < cliff < 50 years)
     */
    function startSale(Sale memory sale, VestingConfig memory vestingConfig) public returns (uint256 saleId) {
        saleId = uint256(keccak256(abi.encode(sale)));

        if (address(vestingConfig.vestingContract) == address(0)) {
            vestingConfig.vestingContract = _makeVestingContract(sale);
        } else {
            if (!vestingConfig.vestingContract.hasRole(vestingConfig.vestingContract.ROLE_CREATE_SCHEDULE(), address(this))) {
                revert UnmanageableVestingContract();
            }
            if (address(vestingConfig.vestingContract.nativeToken()) != address(sale.auctionToken)) {
                revert IncompatibleVestingContract();
            }
        }

        if (vestingConfig.cliff < 7 days || vestingConfig.cliff > 50 * (365 days)) {
            revert InvalidDuration();
        }

        salesVesting[saleId] = vestingConfig;
        saleId = super.startSale(sale);
    }

    function _afterSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId]);
    }

    function settle(uint256 saleId) public virtual override {
        super.settle(saleId);
        if (_saleInfo[saleId].state == SaleState.FAILED) {
            return;
        }

        Sale memory sale = _sales[saleId];
        bool result = sale.auctionToken.approve(address(salesVesting[saleId].vestingContract), sale.salesAmount);
        if (!result) {
            revert ApprovalFailed();
        }
    }

    /**
     * @dev will send auction tokens to the configured vesting contract. Only the cliff is configured.
     *
     * @param saleId sale id
     * @param tokenAmount amount of tokens to vest
     */
    function _claimAuctionTokens(uint256 saleId, uint256 tokenAmount) internal virtual override {
        VestingConfig memory vesting = salesVesting[saleId];

        //the vesting start time is the official auction closing time
        //https://discord.com/channels/608198475598790656/1021413298756923462/1107442747687829515
        if (block.timestamp > _sales[saleId].closingTime + vesting.cliff) {
            //no need for vesting when cliff already expired.
            _sales[saleId].auctionToken.safeTransfer(msg.sender, tokenAmount);
        } else {
            _sales[saleId].auctionToken.safeTransfer(address(vesting.vestingContract), tokenAmount);
            vesting.vestingContract.createVestingSchedule(
                msg.sender, _sales[saleId].closingTime, vesting.cliff, vesting.cliff, 60, false, tokenAmount
            );
        }
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

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

    event Started(uint256 saleId, address indexed issuer, Sale sale, VestingConfig vesting);
    event VestingContractCreated(TokenVesting vestingContract, IERC20 indexed underlyingToken);

    /**
     * @notice if vestingConfig.vestingContract is 0x0, a new vesting contract is automatically created
     *
     * @param sale sale configuration
     * @param vestingConfig vesting configuration. Duration must be compatible to TokenVesting hard requirements (7 days < cliff < 50 years)
     */
    function startSale(Sale memory sale, VestingConfig memory vestingConfig) public returns (uint256 saleId) {
        saleId = uint256(keccak256(abi.encode(sale)));

        if (address(vestingConfig.vestingContract) == address(0)) {
            vestingConfig.vestingContract = _makeVestingContract(sale.auctionToken);
        } else {
            if (!vestingConfig.vestingContract.hasRole(vestingConfig.vestingContract.ROLE_CREATE_SCHEDULE(), address(this))) {
                revert UnmanageableVestingContract();
            }
            if (address(vestingConfig.vestingContract.nativeToken()) != address(sale.auctionToken)) {
                revert IncompatibleVestingContract();
            }
        }

        // duration must follow the same rules as `TokenVesting`
        if (vestingConfig.cliff < 7 days || vestingConfig.cliff > 50 * (365 days)) {
            revert InvalidDuration();
        }

        salesVesting[saleId] = vestingConfig;
        saleId = super.startSale(sale);
    }

    function _afterSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId]);
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

    /**
     * @dev deploys a new vesting schedule contract for the auctionToken
     *      to save on gas and improve UX, this should only be called once per auctionToken.
     *      If a vesting contract already exists for that token, you can provide it when initializing the sale.
     *      Cannot use minimal clones here because TokenVesting is not initializeable
     * @param auctionToken the auction token that a vesting contract is created for
     */
    function _makeVestingContract(IERC20Metadata auctionToken) private returns (TokenVesting vestingContract) {
        vestingContract = new TokenVesting(
            auctionToken,
            string(abi.encodePacked("Vested ", auctionToken.name())),
            string(abi.encodePacked("v", auctionToken.symbol()))
        );
        emit VestingContractCreated(vestingContract, auctionToken);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { TimelockedToken } from "../TimelockedToken.sol";
import { CrowdSale, Sale } from "./CrowdSale.sol";

struct VestingConfig {
    TimelockedToken vestingContract;
    // a duration in seconds, counted from the sale's closing time
    uint256 cliff;
}

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
    address immutable lockingTokenImplementation = address(new TimelockedToken());

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale, VestingConfig locking);
    event VestingContractCreated(TimelockedToken indexed lockingContract, IERC20Metadata indexed underlyingToken);

    /**
     * @notice if vestingContract is 0x0, a new vesting contract is automatically created
     *
     * @param sale sale configuration
     * @param lockedTokenContract the timelock contract to use or address(0) to spawn a new one
     * @param cliff a duration after that the receiver can redeem their tokens
     * @return saleId the newly created sale's id
     */
    function startSale(Sale calldata sale, TimelockedToken lockedTokenContract, uint256 cliff) public returns (uint256 saleId) {
        saleId = uint256(keccak256(abi.encode(sale)));

        if (address(lockedTokenContract) == address(0)) {
            lockedTokenContract = _makeNewLockedTokenContract(sale.auctionToken);
        } else {
            if (address(lockedTokenContract.underlyingToken()) != address(sale.auctionToken)) {
                revert IncompatibleVestingContract();
            }
        }

        salesVesting[saleId] = VestingConfig(lockedTokenContract, cliff);
        saleId = super.startSale(sale);
    }

    function _afterSaleStarted(uint256 saleId) internal virtual override {
        emit Started(saleId, msg.sender, _sales[saleId], salesVesting[saleId]);
    }

    function _afterSaleSettled(uint256 saleId) internal override {
        Sale storage sale = _sales[saleId];
        sale.auctionToken.approve(address(salesVesting[saleId].vestingContract), sale.salesAmount);
    }

    /**
     * @dev will send auction tokens to the configured timelock contract.
     *
     * @param saleId sale id
     * @param tokenAmount amount of tokens to vest
     */
    function _claimAuctionTokens(uint256 saleId, uint256 tokenAmount) internal virtual override {
        VestingConfig storage vestingConfig = salesVesting[saleId];

        //the vesting start time is the official auction closing time
        if (block.timestamp > _sales[saleId].closingTime + vestingConfig.cliff) {
            //no need for vesting when cliff already expired.
            _sales[saleId].auctionToken.safeTransfer(msg.sender, tokenAmount);
        } else {
            //_sales[saleId].auctionToken.safeTransfer(address(vesting.lockingContract), tokenAmount);

            vestingConfig.vestingContract.lock(msg.sender, tokenAmount, uint64(_sales[saleId].closingTime + vestingConfig.cliff));
        }
    }

    /**
     * @dev deploys a new timelocked token contract for the auctionToken
     *      to save on gas and improve UX, this should only be called once per auctionToken.
     *      If a timelocked token contract already exists for auctionToken, you can provide it when initializing the sale.
     * @param auctionToken the auction token that a timelocked token contract is created for
     * @return lockedTokenContract address of the new timelocked token contract
     */
    function _makeNewLockedTokenContract(IERC20Metadata auctionToken) private returns (TimelockedToken lockedTokenContract) {
        lockedTokenContract = TimelockedToken(Clones.clone(lockingTokenImplementation));
        lockedTokenContract.initialize(auctionToken);
        emit VestingContractCreated(lockedTokenContract, auctionToken);
    }
}

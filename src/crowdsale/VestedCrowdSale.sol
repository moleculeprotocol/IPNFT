// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TokenVesting } from "@moleculeprotocol/token-vesting/TokenVesting.sol";
import { CrowdSale, Sale } from "./CrowdSale.sol";

struct VestingConfig {
    TokenVesting vestingContract;
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

    event Started(uint256 indexed saleId, address indexed issuer, Sale sale, VestingConfig vesting);
    event VestingContractCreated(TokenVesting vestingContract, IERC20Metadata indexed underlyingToken);

    /**
     * @notice if vestingContract is 0x0, a new vesting contract is automatically created
     *
     * @param sale sale configuration
     * @param vestingContract the vesting contract to use or address(0) to spawn a new one
     * @param cliff must be compatible to TokenVesting hard requirements (7 days < cliff < 50 years)
     * @return saleId the newly created sale's id
     */
    function startSale(Sale calldata sale, TokenVesting vestingContract, uint256 cliff) public returns (uint256 saleId) {
        saleId = uint256(keccak256(abi.encode(sale)));

        if (address(vestingContract) == address(0)) {
            vestingContract = _makeVestingContract(sale.auctionToken);
        } else {
            if (!vestingContract.hasRole(vestingContract.ROLE_CREATE_SCHEDULE(), address(this))) {
                revert UnmanageableVestingContract();
            }
            if (address(vestingContract.nativeToken()) != address(sale.auctionToken)) {
                revert IncompatibleVestingContract();
            }
        }

        // duration must follow the same rules as `TokenVesting`
        if (cliff < 7 days || cliff > 50 * (365 days)) {
            revert InvalidDuration();
        }

        salesVesting[saleId] = VestingConfig(vestingContract, cliff);
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
        VestingConfig storage vesting = salesVesting[saleId];

        //the vesting start time is the official auction closing time
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
     *      Cannot use minimal clones here because TokenVesting is not initializable
     * @param auctionToken the auction token that a vesting contract is created for
     */
    function _makeVestingContract(IERC20Metadata auctionToken) private returns (TokenVesting vestingContract) {
        vestingContract = new TokenVesting(
            auctionToken,
            string.concat("Vested ", auctionToken.name()),
            string.concat("v", auctionToken.symbol())
        );
        emit VestingContractCreated(vestingContract, auctionToken);
    }
}

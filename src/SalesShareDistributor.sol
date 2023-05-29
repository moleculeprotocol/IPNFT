// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC1155Supply } from "./IERC1155Supply.sol";

import { FractionalizedToken, Metadata } from "./FractionalizedToken.sol";

import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "./Permissioner.sol";

struct Sales {
    uint256 fulfilledListingId;
    IERC20 paymentToken;
    uint256 paidPrice;
    IPermissioner permissioner;
}

error ListingNotFulfilled();
error ListingMismatch();
error InsufficientBalance();
error UncappedToken();
error OnlyIssuer();

error NotClaimingYet();

contract SalesShareDistributor is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    SchmackoSwap private schmackoSwap;

    mapping(address => Sales) public sales;

    event SalesActivated(address indexed fractionToken, address paymentToken, uint256 paidPrice);
    event SharesClaimed(address indexed fractionToken, address indexed claimer, uint256 amount);

    function initialize(SchmackoSwap _schmackoSwap) public {
        schmackoSwap = _schmackoSwap;
    }

    /**
     * @notice returns the `amount` of `paymentToken` that `tokenHolder` can claim by burning their fractions
     *
     * @param tokenContract address
     * @param holder address
     */
    function claimableTokens(FractionalizedToken tokenContract, address holder) public view returns (IERC20 paymentToken, uint256 amount) {
        Sales storage _sales = sales[address(tokenContract)];

        if (address(_sales.paymentToken) == address(0)) {
            revert NotClaimingYet();
        }

        uint256 balance = tokenContract.balanceOf(holder);

        return (_sales.paymentToken, (balance * _sales.paidPrice) / tokenContract.totalIssued());
    }

    /**
     * @notice call during claiming phase to burn all fractions and receive the pro rata sales share
     * @param permissions bytes data that can be read and verified by the configured permissioner
     *        at the moment this simply is a valid signature over a `specificTermsV1` message
     */
    function claim(FractionalizedToken tokenContract, bytes memory permissions) public nonReentrant {
        uint256 balance = tokenContract.balanceOf(_msgSender());
        if (balance < 1000) {
            revert InsufficientBalance();
        }
        Sales storage _sales = sales[address(tokenContract)];

        (IERC20 paymentToken, uint256 erc20shares) = claimableTokens(tokenContract, _msgSender());

        _sales.permissioner.accept(tokenContract, _msgSender(), permissions);

        if (erc20shares < 1000) {
            //this is very hard to simulate because the condition above will already yield 0
            revert InsufficientBalance();
        }
        emit SharesClaimed(address(tokenContract), _msgSender(), balance);
        tokenContract.burnFrom(_msgSender(), balance);
        paymentToken.safeTransfer(_msgSender(), erc20shares);
    }

    /**
     * @notice anyone should be able to call this function after having observed the sale
     *         rn we restrict it to the token issuer since they must provide a permissioner that controls the claiming rules
     *         this is a deep dependency on our own sales contract
     *
     * @param tokenContract FractionalizedToken     the fraction token
     * @param listingId     uint256     the listing id on Schmackoswap
     * @param permissioner  IPermissioner   the permissioner that permits claims
     */
    function afterSale(FractionalizedToken tokenContract, uint256 listingId, IPermissioner permissioner) external {
        if (_msgSender() != tokenContract.issuer()) {
            revert OnlyIssuer();
        }

        Metadata memory metadata = tokenContract.metadata();
        (, uint256 ipnftId,,, IERC20 _paymentToken, uint256 askPrice, address beneficiary, ListingState listingState) =
            schmackoSwap.listings(listingId);

        if (listingState != ListingState.FULFILLED) {
            revert ListingNotFulfilled();
        }
        if (ipnftId != metadata.ipnftId) {
            revert ListingMismatch();
        }
        if (beneficiary != address(this)) {
            revert InsufficientBalance();
        }

        _startClaimingPhase(tokenContract, listingId, _paymentToken, askPrice, permissioner);
    }

    //audit: ensure that no one can withdraw arbitrary amounts here
    //by simply creating a new fractionalization and claim an arbitrary value

    /**
     * @notice When the sales beneficiary has not been set to the underlying erc20 token address but to the original owner's wallet instead,
     *         they can invoke this method to start the claiming phase manually. This e.g. allows sales off the record.
     *
     *         Requires the originalOwner to behave honestly / in favor of the fraction holders
     *         Requires the caller to have approved `price` of `paymentToken` to this contract
     *
     * @param   tokenContract FractionalizedToken  the fraction token contract
     * @param   paymentToken  IERC20   the payment token contract address
     * @param   paidPrice         uint256  the price the NFT has been sold for
     * @param permissioner  IPermissioner   the permissioner that permits claims
     */
    function afterSale(FractionalizedToken tokenContract, IERC20 paymentToken, uint256 paidPrice, IPermissioner permissioner) external nonReentrant {
        if (_msgSender() != tokenContract.issuer()) {
            revert OnlyIssuer();
        }

        Metadata memory metadata = tokenContract.metadata();

        //create a fake (but valid) schmackoswap listing id
        uint256 fulfilledListingId = uint256(
            keccak256(
                abi.encode(
                    SchmackoSwap.Listing(
                        IERC1155Supply(address(0)), //this should be the IPNFT address
                        metadata.ipnftId,
                        _msgSender(),
                        uint256(1),
                        paymentToken,
                        paidPrice,
                        address(this),
                        ListingState.FULFILLED
                    ),
                    block.number
                )
            )
        );
        _startClaimingPhase(tokenContract, fulfilledListingId, paymentToken, paidPrice, permissioner);
        paymentToken.safeTransferFrom(_msgSender(), address(this), paidPrice);
    }

    function _startClaimingPhase(
        FractionalizedToken tokenContract,
        uint256 fulfilledListingId,
        IERC20 _paymentToken,
        uint256 price,
        IPermissioner permissioner
    ) internal {
        if (!tokenContract.capped()) {
            revert UncappedToken();
        }
        sales[address(tokenContract)] = Sales(fulfilledListingId, _paymentToken, price, permissioner);
        emit SalesActivated(address(tokenContract), address(_paymentToken), price);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

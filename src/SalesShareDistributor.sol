// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IERC1155Supply } from "./IERC1155Supply.sol";
import { FractionalizedToken } from "./FractionalizedToken.sol";
import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";
import { TermsAcceptedPermissioner } from "./Permissioner.sol";

struct Sales {
    uint256 fulfilledListingId;
    IERC20 paymentToken;
    uint256 paidPrice;
}

error ListingNotFulfilled();
error ListingMismatch();
error InsufficientBalance();
error MustOwnIpnft();
error NotClaimingYet();

contract SalesShareDistributor is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    SchmackoSwap private schmackoSwap;
    TermsAcceptedPermissioner private permissioner;

    mapping(address => Sales) sales;

    event SalesActivated(address indexed fractionToken, address paymentToken, uint256 paidPrice);
    event SharesClaimed(address indexed fractionToken, address indexed claimer, uint256 amount);

    function initialize(SchmackoSwap _schmackoSwap, TermsAcceptedPermissioner _permissioner) public {
        schmackoSwap = _schmackoSwap;
        permissioner = _permissioner;
    }

    /**
     * @notice returns the `amount` of `paymentToken` that `tokenHolder` can claim by burning their fractions
     *
     * @param tokenContract address
     * @param holder address
     */
    function claimableTokens(FractionalizedToken tokenContract, address holder) public view returns (IERC20 paymentToken, uint256 amount) {
        Sales memory _sales = sales[address(tokenContract)];

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
    function claim(FractionalizedToken tokenContract, bytes memory permissions) public {
        uint256 balance = tokenContract.balanceOf(_msgSender());
        if (balance == 0) {
            revert InsufficientBalance();
        }

        permissioner.accept(tokenContract, _msgSender(), permissions);

        (IERC20 paymentToken, uint256 erc20shares) = claimableTokens(tokenContract, _msgSender());
        if (erc20shares == 0) {
            //todo: this is very hard to simulate because the condition above will already yield 0
            revert InsufficientBalance();
        }
        emit SharesClaimed(address(tokenContract), _msgSender(), balance);
        //todo this needs approval, again
        tokenContract.burnFrom(_msgSender(), balance);
        paymentToken.safeTransfer(_msgSender(), erc20shares);
    }

    /**
     * @notice When the sales beneficiary has been set to this contract,
     *         anyone can call this function after having observed the sale
     *         this is a deep dependency on our own sales contract
     *
     * @param tokenContract FractionalizedToken     the fraction token
     * @param listingId     uint256     the listing id on Schmackoswap
     */
    function afterSale(FractionalizedToken tokenContract, uint256 listingId) external {
        (uint256 fractionalizedIpnftId,,) = tokenContract.metadata();
        (, uint256 ipnftId,,, IERC20 _paymentToken, uint256 askPrice, address beneficiary, ListingState listingState) =
            schmackoSwap.listings(listingId);

        if (listingState != ListingState.FULFILLED) {
            revert ListingNotFulfilled();
        }
        if (ipnftId != fractionalizedIpnftId) {
            revert ListingMismatch();
        }
        if (beneficiary != address(this)) {
            revert InsufficientBalance();
        }

        _startClaimingPhase(tokenContract, listingId, _paymentToken, askPrice);
    }

    /**
     * @notice When the sales beneficiary has not been set to the underlying erc20 token address but to the original owner's wallet instead,
     *         they can invoke this method to start the claiming phase manually. This e.g. allows sales off the record.
     *
     *         Requires the originalOwner to behave honestly / in favor of the fraction holders
     *         Requires the caller to have approved `price` of `paymentToken` to this contract
     *
     * @param   tokenContract address  the fraction token contract
     * @param   paymentToken  IERC20   the payment token contract address
     * @param   price         uint256  the price the NFT has been sold for
     */
    function afterSale(FractionalizedToken tokenContract, IERC20 paymentToken, uint256 price) external nonReentrant {
        Sales memory _sales = sales[address(tokenContract)];
        (uint256 ipnftId, address originalOwner,) = tokenContract.metadata();
        if (_msgSender() != originalOwner) {
            revert MustOwnIpnft();
        }

        //create a fake (but valid) schmackoswap listing id
        uint256 fulfilledListingId = uint256(
            keccak256(
                abi.encode(
                    SchmackoSwap.Listing(
                        IERC1155Supply(address(0)), //this should be the IPNFT address
                        ipnftId,
                        _msgSender(),
                        uint256(1),
                        _sales.paymentToken,
                        _sales.paidPrice,
                        address(this),
                        ListingState.FULFILLED
                    ),
                    block.number
                )
            )
        );
        _startClaimingPhase(tokenContract, fulfilledListingId, paymentToken, price);
        paymentToken.safeTransferFrom(_msgSender(), address(this), price);
    }

    function _startClaimingPhase(FractionalizedToken tokenContract, uint256 fulfilledListingId, IERC20 _paymentToken, uint256 price) internal {
        sales[address(tokenContract)] = Sales(fulfilledListingId, _paymentToken, price);
        emit SalesActivated(address(tokenContract), address(_paymentToken), price);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

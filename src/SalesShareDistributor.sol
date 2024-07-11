// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPNFT } from "./IPNFT.sol";
import { IPToken, Metadata } from "./IPToken.sol";
import { Tokenizer, MustControlIpnft } from "./Tokenizer.sol";
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
error NotSalesBeneficiary();
error UncappedToken();
error OnlySeller();
error NotClaimingYet();

/**
 * @title SalesShareDistributor
 * @author molecule.xyz
 * @notice THIS IS NOT SAFE TO BE USED IN PRODUCTION!!
 *         This is a one time sell out contract for a "final" IPT sale and requires the IP token to be capped.
 */
contract SalesShareDistributor is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    SchmackoSwap private schmackoSwap;

    mapping(address => Sales) public sales;

    event SalesActivated(address indexed molecules, address paymentToken, uint256 paidPrice);
    event SharesClaimed(address indexed molecules, address indexed claimer, uint256 amount);

    function initialize(SchmackoSwap _schmackoSwap) public {
        schmackoSwap = _schmackoSwap;
    }

    /**
     * @notice returns the `amount` of `paymentToken` that `tokenHolder` can claim by burning their IP Tokens
     *
     * @param tokenContract address
     * @param holder address
     */
    function claimableTokens(IPToken tokenContract, address holder) public view returns (IERC20 paymentToken, uint256 amount) {
        Sales storage _sales = sales[address(tokenContract)];

        if (address(_sales.paymentToken) == address(0)) {
            revert NotClaimingYet();
        }

        uint256 balance = tokenContract.balanceOf(holder);

        return (_sales.paymentToken, (balance * _sales.paidPrice) / tokenContract.totalIssued());
    }

    /**
     * @notice call during claiming phase to burn all molecules and receive the pro rata sales share
     * @param permissions bytes data that can be read and verified by the configured permissioner
     *        at the moment this simply is a valid signature over a `specificTermsV1` message
     */
    function claim(IPToken tokenContract, bytes memory permissions) public nonReentrant {
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
     * @notice release sales shares for a Schmackoswap transaction
     * @dev todo: *anyone* should be able to call this function after having observed the sale; right now we restrict it to the creator of the trade since they were in control of the IPNFT before
     * @dev this has a deep dependency on our own swap contract
     *
     * @param ipt IPToken     the tokenContract of the IPToken
     * @param listingId     uint256     the listing id on Schmackoswap
     * @param permissioner  IPermissioner   the permissioner that permits claims
     */
    function afterSale(IPToken ipt, uint256 listingId, IPermissioner permissioner) external {
        (, uint256 ipnftId, address seller, IERC20 _paymentToken, uint256 askPrice, address beneficiary, ListingState listingState) =
            schmackoSwap.listings(listingId);

        if (_msgSender() != seller) {
            revert OnlySeller();
        }

        if (listingState != ListingState.FULFILLED) {
            revert ListingNotFulfilled();
        }
        Metadata memory metadata = ipt.metadata();
        if (ipnftId != metadata.ipnftId) {
            revert ListingMismatch();
        }
        if (beneficiary != address(this)) {
            revert NotSalesBeneficiary();
        }

        _startClaimingPhase(ipt, listingId, _paymentToken, askPrice, permissioner);
    }

    //audit: ensure that no one can withdraw arbitrary amounts here
    //by simply creating a new IPToken instance and claim an arbitrary value
    //todo: try breaking this by providing a fake IPT with a fake Tokenizer owner
    //todo: this must be called by the beneficiary of a sale we don't control.
    /**
     * @notice When the sales beneficiary has not been set to the underlying erc20 token address but to the original owner's wallet instead,
     *         they can invoke this method to start the claiming phase manually. This e.g. allows sales off the record ("OpenSea").
     *
     *         Requires the originalOwner to behave honestly / in favor of the IPT holders
     *         Requires the caller to have approved `paidPrice` of `paymentToken` to this contract
     *
     * @param   tokenContract IPToken  the IPToken token contract
     * @param   paymentToken  IERC20   the payment token contract address
     * @param   paidPrice     uint256  the price the NFT has been sold for
     * @param   permissioner  IPermissioner   the permissioner that permits claims
     */
    function UNSAFE_afterSale(IPToken tokenContract, IERC20 paymentToken, uint256 paidPrice, IPermissioner permissioner) external nonReentrant {
        Metadata memory metadata = tokenContract.metadata();

        Tokenizer tokenizer = Tokenizer(tokenContract.owner());

        //todo: this should be a selected beneficiary of the IPNFT's sales proceeds, and not the original owner :)
        //idea is to allow *several* sales proceeds to be notified here, create unique sales ids for each and let users claim the all of them at once
        if (_msgSender() != metadata.originalOwner) {
            revert MustControlIpnft();
        }

        //create a fake (but valid) schmackoswap listing id
        uint256 fulfilledListingId = uint256(
            keccak256(
                abi.encode(
                    SchmackoSwap.Listing(
                        IERC721(address(tokenizer.getIPNFTContract())),
                        metadata.ipnftId,
                        _msgSender(),
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

    function _startClaimingPhase(IPToken ipt, uint256 fulfilledListingId, IERC20 _paymentToken, uint256 price, IPermissioner permissioner) internal {
        //todo: this *should* be enforced before a sale starts
        // if (!tokenContract.capped()) {
        //     revert UncappedToken();
        // }
        sales[address(ipt)] = Sales(fulfilledListingId, _paymentToken, price, permissioner);
        emit SalesActivated(address(ipt), address(_paymentToken), price);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

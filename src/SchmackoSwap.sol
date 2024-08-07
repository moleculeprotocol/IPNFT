// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

enum ListingState {
    LISTED,
    CANCELLED,
    FULFILLED
}

/// @title SchmackoSwap
/// @author molecule.to
/// @notice a sales contract that lets NFT holders list items with an ask price and control who can fulfill their offers. Accepts arbitrary ERC20 tokens as payment.
contract SchmackoSwap is ERC165, ReentrancyGuard {
    using SafeERC20 for IERC20;
    /// ERRORS ///

    /// @notice Thrown when user tries to initiate an action without being authorized
    error Unauthorized();

    /// @notice Thrown when trying to purchase a listing that doesn't exist
    error ListingNotFound();

    /// @notice Thrown when the user tries to buy a listing for which they are not approved
    error NotOnAllowlist();

    /// @notice Thrown when the buyer hasn't approved the marketplace to transfer their payment tokens
    error InsufficientAllowance();

    /// EVENTS ///

    /// @notice Emitted when a new listing is created
    /// @param listingId The id of the newly-created listing
    /// @param listing The newly-created listing
    event Listed(uint256 listingId, Listing listing);

    /// @notice Emitted when a listing is cancelled
    /// @param listingId The id of the removed listing
    /// @param listing The removed listing
    event Unlisted(uint256 listingId, Listing listing);

    /// @notice Emitted when a listing is purchased
    /// @param listingId The id of the purchased listing
    /// @param buyer The address of the buyer
    /// @param listing The purchased listing
    event Purchased(uint256 listingId, address indexed buyer, Listing listing);

    /// @notice Emitted when an address is added or removed from the allowlist
    /// @param listingId The listing that is getting updated
    /// @param buyer The address of the buyer that is added
    /// @param _isAllowed If address is added or removed from allowlist
    event AllowlistUpdated(uint256 listingId, address indexed buyer, bool _isAllowed);

    /// @notice Used as a counter for the next sale index.
    /// @dev Initialised at 1 because it makes the first transaction slightly cheaper.
    uint256 internal saleCounter = 1;

    /// @dev Parameters for listings
    /// @param tokenContract The IERC721 contract for the listed token
    /// @param tokenId The ID of the listed token
    /// @param creator The address of the seller
    /// @param askPrice The amount the seller is asking for in exchange for the token
    struct Listing {
        IERC721 tokenContract;
        uint256 tokenId;
        address creator;
        IERC20 paymentToken;
        uint256 askPrice;
        address beneficiary;
        ListingState listingState;
    }

    //mapping(uint256 => mapping(address => bool)) listingOperators;

    /// @notice An indexed list of listings
    mapping(uint256 => Listing) public listings;

    /// @notice An indexed list of allowlist spots
    mapping(uint256 => mapping(address => bool)) allowlist;

    /// @notice Lists the full supply of an ERC1155 token for sale
    /// @param tokenContract The ERC1155 contract for the token you're listing
    /// @param tokenId The ID of the token you're listing
    /// @param askPrice How much you want to receive in exchange for the token
    /// @return The ID of the created listing
    /// @dev Remember to call `setApprovalForAll(<address of this contract>, true)` on the ERC1155's contract before calling this function
    function list(IERC721 tokenContract, uint256 tokenId, IERC20 paymentToken, uint256 askPrice) public returns (uint256) {
        return list(tokenContract, tokenId, paymentToken, askPrice, msg.sender);
    }

    /**
     * {inheritDoc list}
     * @param beneficiary address the account that will receive the funds after fulfillment. In case of synthesis this should be the SharesDistribution contract
     */
    function list(IERC721 tokenContract, uint256 tokenId, IERC20 paymentToken, uint256 askPrice, address beneficiary) public returns (uint256) {
        if (!tokenContract.isApprovedForAll(msg.sender, address(this))) {
            revert InsufficientAllowance();
        }

        Listing memory listing = Listing({
            tokenContract: tokenContract,
            tokenId: tokenId,
            paymentToken: paymentToken,
            askPrice: askPrice,
            creator: msg.sender,
            beneficiary: beneficiary,
            listingState: ListingState.LISTED
        });

        uint256 listingId = uint256(keccak256(abi.encode(listing, block.number)));

        listings[listingId] = listing;

        emit Listed(listingId, listing);

        //todo: this stays unmentioned in the emitted event!
        return listingId;
    }

    /// @notice Cancel an existing listing
    /// @param listingId The ID for the listing you want to cancel
    function cancel(uint256 listingId) public {
        Listing memory listing = listings[listingId];
        if (listing.creator != msg.sender) {
            revert Unauthorized();
        }

        if (listing.listingState != ListingState.LISTED) {
            revert("cant cancel an inactive listing");
        }
        listings[listingId].listingState = ListingState.CANCELLED;
        emit Unlisted(listingId, listings[listingId]);
    }

    /// @notice Purchase one of the listed tokens
    /// @param listingId The ID for the listing you want to purchase
    function fulfill(uint256 listingId) public nonReentrant {
        Listing memory listing = listings[listingId];
        if (listing.creator == address(0)) revert ListingNotFound();
        if (allowlist[listingId][msg.sender] != true) revert NotOnAllowlist();
        if (listing.listingState != ListingState.LISTED) revert("listing not active anymore");

        IERC20 paymentToken = listing.paymentToken;

        listings[listingId].listingState = ListingState.FULFILLED;

        listing.tokenContract.safeTransferFrom(listing.creator, msg.sender, listing.tokenId);
        paymentToken.safeTransferFrom(msg.sender, listing.beneficiary, listing.askPrice);

        emit Purchased(listingId, msg.sender, listings[listingId]);
    }

    /// @notice lets the seller allow or disallow a certain buyer to fulfill the listing
    /// @param listingId The ID for the listing you want to purchase
    /// @param buyerAddress the address to change allowance for
    /// @param _isAllowed whether to allow or disallow `buyerAddress` to fulfill the listing
    function changeBuyerAllowance(uint256 listingId, address buyerAddress, bool _isAllowed) public {
        Listing memory listing = listings[listingId];

        if (listing.creator == address(0)) revert ListingNotFound();
        if (listing.creator != msg.sender) revert Unauthorized();
        require(buyerAddress != address(0), "Can't add ZERO address to allowlist");

        allowlist[listingId][buyerAddress] = _isAllowed;

        emit AllowlistUpdated(listingId, buyerAddress, _isAllowed);
    }

    function changeBuyerAllowance(uint256 listingId, address[] calldata buyerAddresses, bool _isAllowed) external {
        for (uint256 i = 0; i < buyerAddresses.length; i++) {
            changeBuyerAllowance(listingId, buyerAddresses[i], _isAllowed);
        }
    }

    function isAllowed(uint256 listingId, address buyerAddress) public view returns (bool) {
        return allowlist[listingId][buyerAddress];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract SchmackoSwap is ReentrancyGuard {
    /// ERRORS ///

    /// @notice Thrown when user tries to initiate an action without being authorized
    error Unauthorized();

    /// @notice Thrown when trying to purchase a listing that doesn't exist
    error ListingNotFound();

    /// @notice Thrown when the user tries to buy a listing for which they are not approved
    error NotOnAllowlist();

    /// @notice Thrown when the buyer hasn't approved the marketplace to transfer their payment tokens
    error InsufficientAllowance();

    /// @notice Thrown when the buyer has insufficient funds to purchase the listing
    error InsufficientBalance();

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
    event AllowlistUpdated(
        uint256 listingId,
        address indexed buyer,
        bool _isAllowed
    );

    /// @notice Used as a counter for the next sale index.
    /// @dev Initialised at 1 because it makes the first transaction slightly cheaper.
    uint256 internal saleCounter = 1;

    /// @dev Parameters for listings
    /// @param tokenContract The ERC1155 contract for the listed token
    /// @param tokenId The ID of the listed token
    /// @param creator The address of the seller
    /// @param askPrice The amount the seller is asking for in exchange for the token
    struct Listing {
        ERC1155Supply tokenContract;
        uint256 tokenId;
        uint256 tokenAmount;
        address creator;
        ERC20 paymentToken;
        uint256 askPrice;
    }

    /// @notice An indexed list of listings
    mapping(uint256 => Listing) public listings;

    /// @notice An indexed list of allowlist spots
    mapping(uint256 => mapping(address => bool)) allowlist;

    /// @notice List an ERC1155 token for sale
    /// @param tokenContract The ERC1155 contract for the token you're listing
    /// @param tokenId The ID of the token you're listing
    /// @param askPrice How much you want to receive in exchange for the token
    /// @return The ID of the created listing
    /// @dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC1155's contract before calling this function
    function list(
        ERC1155Supply tokenContract,
        uint256 tokenId,
        ERC20 paymentToken,
        uint256 askPrice
    ) public nonReentrant returns (uint256) {
        //TODO: revert if ERC1155 needed interface not implemented

        uint256 tokenSupply = tokenContract.totalSupply(tokenId);

        Listing memory listing = Listing({
            tokenContract: tokenContract,
            tokenId: tokenId,
            tokenAmount: tokenSupply,
            paymentToken: paymentToken,
            askPrice: askPrice,
            creator: msg.sender
        });

        bytes32 _listingId = keccak256(abi.encode(listing));
        // Left the bytes32 -> uint256 conversion in because it was
        // a pain in the ass to refactor everything else to handle bytes32
        uint256 listingId = uint256(_listingId);

        listings[listingId] = listing;

        emit Listed(listingId, listing);

        listing.tokenContract.safeTransferFrom(
            msg.sender,
            address(this),
            listing.tokenId,
            tokenSupply,
            ""
        );

        return listingId;
    }

    /// @notice Cancel an existing listing
    /// @param listingId The ID for the listing you want to cancel
    function cancel(uint256 listingId) public nonReentrant {
        Listing memory listing = listings[listingId];

        if (listing.creator != msg.sender) revert Unauthorized();

        delete listings[listingId];

        emit Unlisted(listingId, listing);

        listing.tokenContract.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId,
            listing.tokenAmount,
            ""
        );
    }

    /// @notice Purchase one of the listed tokens
    /// @param listingId The ID for the listing you want to purchase
    function fulfill(uint256 listingId) public nonReentrant {
        Listing memory listing = listings[listingId];
        if (listing.creator == address(0)) revert ListingNotFound();
        if (allowlist[listingId][msg.sender] != true) revert NotOnAllowlist();

        ERC20 paymentToken = listing.paymentToken;

        uint256 allowance = paymentToken.allowance(msg.sender, address(this));
        if (allowance < listing.askPrice) revert InsufficientAllowance();

        uint256 buyerBalance = paymentToken.balanceOf(msg.sender);
        if (buyerBalance < listing.askPrice) revert InsufficientBalance();

        delete listings[listingId];

        listing.tokenContract.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId,
            listing.tokenAmount,
            ""
        );

        SafeTransferLib.safeTransferFrom(
            paymentToken,
            msg.sender,
            listing.creator,
            listing.askPrice
        );

        emit Purchased(listingId, msg.sender, listing);
    }

    function changeBuyerAllowance(
        uint256 listingId,
        address buyerAddress,
        bool _isAllowed
    ) public {
        Listing memory listing = listings[listingId];

        if (listing.creator == address(0)) revert ListingNotFound();
        if (listing.creator != msg.sender) revert Unauthorized();
        require(
            buyerAddress != address(0),
            "Can't add ZERO address to allowlist"
        );

        allowlist[listingId][buyerAddress] = _isAllowed;

        emit AllowlistUpdated(listingId, buyerAddress, _isAllowed);
    }

    function isAllowed(uint256 listingId, address buyerAddress)
        public
        view
        returns (bool)
    {
        return allowlist[listingId][buyerAddress];
    }

    // Implemented these functions so we don't get "execution reverted: ERC1155: transfer to non ERC1155Receiver implementer"
    // when transferring ERC1155 tokens to this contract

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
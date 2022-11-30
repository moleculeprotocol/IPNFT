// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "erc721b/extensions/ERC721BBaseTokenURI.sol";
import "erc721b/extensions/ERC721BBurnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MintpassV2 is Ownable, ERC721BBaseTokenURI, ERC721BBurnable, ReentrancyGuard {
    /// @dev Stores the address of the associated IP-NFT contract.
    address public ipnftContract;

    // Mapping from tokenId to validity of token. If tokenId has been revoked, it will return true
    mapping(uint256 => bool) private _revocations;

    mapping(uint256 => bool) private _redemptions;

    constructor(address ipnftContract_) ERC721BBaseTokenURI() {
        ipnftContract = ipnftContract_;
    }

    /**
     *
     * EVENTS
     *
     */

    /// Event emitted when token `tokenId` of `owner` is revoked
    /// @param tokenId Identifier of the token
    event Revoked(uint256 indexed tokenId);

    /// Event emitted when new token is minted
    /// @param owner Address for whom the ownership has been revoked
    /// @param tokenId Identifier of the token
    event TokenMinted(address indexed owner, uint256 indexed tokenId);

    /// Event emitted when token is burned
    /// @param from Address that burned the token
    /// @param tokenId Identifier of the token
    event TokenBurned(address indexed from, uint256 indexed tokenId);

    event TokenRedeemed(uint256 indexed tokenId);

    /**
     *
     * PUBLIC
     *
     */

    /// @dev Check if a token hasn't been revoked
    /// @param tokenId Identifier of the token that is checked for validity
    /// @return True if the token is valid, false otherwise
    function isRedeemable(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        return !_revocations[tokenId] && !_redemptions[tokenId];
    }

    function batchMint(address to, uint256 quantity) external nonReentrant onlyOwner {
        uint256 tokenId = totalSupply() + 1;

        _safeMint(to, quantity);

        _setApprovalForAll(to, ipnftContract, true);

        for (uint256 i = 0; i < quantity; i++) {
            emit TokenMinted(to, tokenId);
            tokenId++;
        }
    }

    /// @dev Mark the token as revoked
    /// @param tokenId Identifier of the token
    function revoke(uint256 tokenId) external onlyOwner {
        require(isRedeemable(tokenId), "Token is already redeemed or revoked");
        _revocations[tokenId] = true;
        emit Revoked(tokenId);
    }

    function redeem(uint256 tokenId) public {
        require(msg.sender == address(ipnftContract), "Only IPNFT contract can set to redeemed");
        require(isRedeemable(tokenId), "Token is already redeemed or revoked");
        _redemptions[tokenId] = true;
        emit TokenRedeemed(tokenId);
    }

    /// @dev Returns the tokenURI attached to a token
    /// @param tokenId Identifier of the token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory imageURI;

        if (_redemptions[tokenId]) {
            imageURI = "ipfs://imageToShowWhenRedeemed";
        } else {
            imageURI = "ipfs://imageToShowWhenNotRedeemed";
        }

        require(_exists(tokenId), "Token does not exist");
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "IP-NFT Mintpass #',
                        Strings.toString(tokenId),
                        '", "description": "This Mintpass can be used to mint one IP-NFT", "external_url": "TODO: Enter IP-NFT-UI URL", "image": "TODO: imageURI", "valid": ',
                        _revocations[tokenId] ? "false" : "true",
                        '", "redeemed": ',
                        _redemptions[tokenId] ? "false" : "true" "}"
                    )
                )
            )
        );
    }

    /// @dev burns a token. This is only possible by either the owner of the token or the IP-NFT Contract
    /// @param tokenId Identifier of the token to be burned
    function burn(uint256 tokenId) public virtual override {
        super.burn(tokenId);
        emit TokenBurned(msg.sender, tokenId);
    }

    function name() external pure returns (string memory) {
        return "IP-NFT Mintpass";
    }

    function symbol() external pure returns (string memory) {
        return "MNTPSS";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721B, IERC165) returns (bool) {
        return interfaceId == type(IERC721Metadata).interfaceId || super.supportsInterface(interfaceId);
    }

    function totalSupply() public view virtual override (ERC721B, ERC721BBurnable) returns (uint256) {
        return super.totalSupply();
    }

    function _exists(uint256 tokenId) internal view virtual override (ERC721B, ERC721BBurnable) returns (bool) {
        return super._exists(tokenId);
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override (ERC721B, ERC721BBurnable, IERC721)
        returns (address)
    {
        return super.ownerOf(tokenId);
    }

    /**
     *
     * INTERNAL
     *
     */

    /// @dev Hook that is called before every token transfer. This includes minting and burning.
    /// It checks if the token is minted or burned. If not the function is reverted.
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 amount)
        internal
        virtual
        override
    {
        require(from == address(0) || to == address(0), "This a Soulbound token. It can only be burned.");
        super._beforeTokenTransfers(from, to, startTokenId, amount);
    }
}

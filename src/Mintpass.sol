// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "erc721b/extensions/ERC721BBaseTokenURI.sol";
import "erc721b/extensions/ERC721BBurnable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Mintpass is AccessControl, ERC721BBaseTokenURI, ERC721BBurnable {
    error AlreadyRedeemed();
    error NotRedeemable();
    error NotOwningMintpass(uint256 id);
    error MintPassRevoked(uint256 id);

    bytes32 public constant MODERATOR = keccak256("MODERATOR");
    bytes32 public constant REDEEMER = keccak256("REDEEMER");

    enum Status {
        DEFAULT, //0
        REDEEMED,
        REVOKED
    }

    // Mapping from tokenId to validity of token.
    mapping(uint256 => Status) private _status;

    constructor(address ipnftContract_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REDEEMER, ipnftContract_);
    }

    /**
     *
     * EVENTS
     *
     */
    event Revoked(uint256 indexed tokenId);
    event Redeemed(uint256 indexed tokenId);
    event Burned(uint256 indexed tokenId);

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
        return _status[tokenId] == Status.DEFAULT;
    }

    function batchMint(address to, uint256 amount) external onlyRole(MODERATOR) {
        _safeMint(to, amount);
    }

    function authorizeMint(address to, uint256 mintPassId) public view onlyRole(REDEEMER) returns (bool) {
        if (ownerOf(mintPassId) != to) {
            revert NotOwningMintpass(mintPassId);
        }
        if (!isRedeemable(mintPassId)) {
            revert MintPassRevoked(mintPassId);
        }
        return true;
    }

    /// @dev Mark the token as revoked
    /// @param tokenId Identifier of the token
    function revoke(uint256 tokenId) external onlyRole(MODERATOR) {
        if (!isRedeemable(tokenId)) {
            revert NotRedeemable();
        }
        _status[tokenId] = Status.REVOKED;
        emit Revoked(tokenId);
    }

    function redeem(uint256 tokenId) public onlyRole(REDEEMER) {
        if (!isRedeemable(tokenId)) {
            revert NotRedeemable();
        }
        _status[tokenId] = Status.REDEEMED;
        emit Redeemed(tokenId);
    }

    /// @dev Returns the tokenURI attached to a token
    /// @param tokenId Identifier of the token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory statusString = "redeemable";
        if (_status[tokenId] == Status.REVOKED) {
            statusString = "revoked";
        }
        if (_status[tokenId] == Status.REDEEMED) {
            statusString = "redeemed";
        }

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "IP-NFT Mintpass #',
                        Strings.toString(tokenId),
                        '", "description": "This Mintpass can be used to mint one IP-NFT", "external_url": "https://molecule.to", "image": "',
                        isRedeemable(tokenId)
                            ? "ar://K8ZyU9fWSMgEx0bDRmwd0sXGm1PKb_Dr2B-27yMqy3Y"
                            : "ar://g-ZF9NewUio2B74ChCQN0x0cj3liZPxj0H7wH-v5y98",
                        '", "attributes": [{ "trait_type": "Status", "value": "',
                        statusString,
                        '"}]}'
                    )
                )
            )
        );
    }

    function name() public pure returns (string memory) {
        return "IP-NFT Mintpass";
    }

    function symbol() public pure returns (string memory) {
        return "IPNFTMNTPSS";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721B, IERC165, AccessControl) returns (bool) {
        return interfaceId == type(IERC721Metadata).interfaceId || super.supportsInterface(interfaceId);
    }

    function totalSupply() public view virtual override (ERC721B, ERC721BBurnable) returns (uint256) {
        return super.totalSupply();
    }

    function _exists(uint256 tokenId) internal view virtual override (ERC721B, ERC721BBurnable) returns (bool) {
        return super._exists(tokenId);
    }

    function ownerOf(uint256 tokenId) public view virtual override (ERC721B, ERC721BBurnable, IERC721) returns (address) {
        return super.ownerOf(tokenId);
    }

    /**
     *
     * INTERNAL
     *
     */

    /// @dev Hook that is called before every token transfer. This includes minting and burning.
    /// It checks if the token is minted or burned. If not the function is reverted.
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 amount) internal virtual override {
        require(from == address(0) || to == address(0), "This a Soulbound token. It can only be burned.");
        super._beforeTokenTransfers(from, to, startTokenId, amount);
    }
}

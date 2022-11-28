// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ReentrancyGuard } from
    "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Mintpass is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    /// @dev Stores the address of the associated IP-NFT contract.
    address public _ipnftContract;

    // Mapping from tokenId to validity of token. If tokenId has been revoked, it will return true
    mapping(uint256 => bool) private _revocations;

    constructor(address ipnftContract) ERC721("IP-NFT Mintpass", "IPNFTMP") {
        _ipnftContract = ipnftContract;
        _tokenIdCounter.increment();
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

    /**
     *
     * PUBLIC
     *
     */

    /// @dev Check if a token hasn't been revoked
    /// @param tokenId Identifier of the token that is checked for validity
    /// @return True if the token is valid, false otherwise
    function isValid(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        return !_revocations[tokenId];
    }

    /// @dev Mints a token to an address and approves it be handled by the IP-NFT Contract
    /// @param to The address that the token is minted to
    function safeMint(address to)
        public
        nonReentrant
        onlyOwner
        returns (uint256)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _approve(_ipnftContract, tokenId);
        emit TokenMinted(to, tokenId);

        return tokenId;
    }

    /// @dev Mints a number of tokens to an address and approves it be handled by the IP-NFT Contract
    /// @param to The address that the token is minted to
    /// @param amount the amount of tokens to mint
    function batchMint(address to, uint256 amount)
        public
        nonReentrant
        onlyOwner
    {
        require(amount < 100, "Don't go crazy with the mints");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
            _approve(_ipnftContract, tokenId);
            emit TokenMinted(to, tokenId);
        }
    }

    /// @dev Mark the token as revoked
    /// @param tokenId Identifier of the token
    function revoke(uint256 tokenId) external onlyOwner {
        require(isValid(tokenId), "Token is already invalid");
        _revocations[tokenId] = true;
        emit Revoked(tokenId);
    }

    /// @dev burns a token. This is only possible by either the owner of the token or the IP-NFT Contract
    /// @param tokenId Identifier of the token to be burned
    function burn(uint256 tokenId) external {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Not authorized to burn this token"
        );
        _burn(tokenId);
        emit TokenBurned(msg.sender, tokenId);
    }

    /// @dev Returns the tokenURI attached to a token
    /// @param tokenId Identifier of the token
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Token does not exist");
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "IP-NFT Mintpass #',
                        Strings.toString(tokenId),
                        '", "description": "This Mintpass can be used to mint one IP-NFT", "external_url": "TODO: Enter IP-NFT-UI URL", "image": "TODO: Enter IPFS URL", "valid": ',
                        _revocations[tokenId] ? "false" : "true",
                        "}"
                    )
                )
            )
        );
    }

    /**
     *
     * INTERNAL
     *
     */

    /// @dev Hook that is called before every token transfer. This includes minting and burning.
    /// It checks if the token is minted or burned. If not the function is reverted.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        require(
            from == address(0) || to == address(0),
            "This a Soulbound token. It can only be burned."
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}

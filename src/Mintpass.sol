// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

contract Mintpass is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    /// @dev Stores the address of the associated IP-NFT contract.
    // Stores the contract address of the IP-NFT Contract
    address private _ipnftContract;

    // Mapping from tokenId to validity of token
    mapping(uint256 => bool) private _isTokenValid;

    // Mapping from owner to number of valid tokens
    mapping(address => uint256) private _numberOfValidTokens;

    constructor(address ipnftContract_) ERC721("Mintpass", "MP") {
        _ipnftContract = ipnftContract_;
    }

    /**
     *
     * EVENTS
     *
     */

    /// @notice Event emitted when token `tokenId` of `owner` is revoked
    /// @param owner Address for whom the ownership has been revoked
    /// @param tokenId Identifier of the token
    event Revoked(address owner, uint256 tokenId);

    /**
     *
     * PUBLIC
     *
     */

    /// @notice Check if a token hasn't been revoked
    /// @param tokenId Identifier of the token that is checked for validity
    /// @return True if the token is valid, false otherwise
    function isValid(uint256 tokenId) external view returns (bool) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return _isTokenValid[tokenId];
    }

    /// @notice Check if an address owns a valid token in the contract
    /// @param owner Address for whom to check the ownership
    /// @return True if `owner` has a valid token, false otherwise
    function hasValid(address owner) public view virtual returns (bool) {
        return _numberOfValidTokens[owner] > 0;
    }

    /// @notice Mints a token to an address and approves it be handled by the IP-NFT Contract
    /// @param to The address that the token is minted to
    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _isTokenValid[tokenId] = true;
        _numberOfValidTokens[to] += 1;
        _safeMint(to, tokenId);
        _approve(_ipnftContract, tokenId);
    }

    /// @notice Mark the token as revoked
    /// @param tokenId Identifier of the token
    function revoke(uint256 tokenId) external onlyOwner {
        address _owner = ownerOf(tokenId);
        require(_isTokenValid[tokenId], "Token is already invalid");

        assert(_numberOfValidTokens[_owner] > 0);
        _numberOfValidTokens[_owner] -= 1;
        _isTokenValid[tokenId] = false;
        emit Revoked(_owner, tokenId);
    }

    /// @notice burns a token. This is only possible by either the owner of the token or the IP-NFT Contract
    /// @param tokenId Identifier of the token to be burned
    function burn(uint256 tokenId) external {
        if (ownerOf(tokenId) == msg.sender || msg.sender == _ipnftContract) {
            _burn(tokenId);
        } else {
            revert("Only the owner or ipnft contract can burn this token.");
        }
    }

    function numberOfValidTokens(address owner) public view returns (uint256) {
        return _numberOfValidTokens[owner];
    }

    /// @notice Returns the tokenURI attached to a token
    /// @param tokenId Identifier of the token
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            ownerOf(tokenId) != address(0), "This token is not owned by anyone"
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "Mintpass to create an IP-NFT", "description": "This Mintpass can be used to mint an IP-NFT. The Mintpass will get burned during the process", "external_url": "TODO: Enter IP-NFT-UI URL", "image":"TODO: Enter IPFS URL", "tokenId":"}',
                        tokenId,
                        '"}'
                    )
                )
            )
        );
    }

    // Returns the address to the associated IP-NFT Contract
    function getAssociatedIPNFTContractAddress()
        public
        view
        returns (address)
    {
        return _ipnftContract;
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

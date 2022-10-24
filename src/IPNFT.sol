// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract IPNFT is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ERC721Burnable
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 private _price = 0 ether;
    mapping(uint => bool) public frozen;

    event TokenURIUpdated(uint256 tokenId, string tokenUri);
    event TokenMinted(uint256 tokenId, string tokenUri, address owner, bool frozen);
    event PermanentURI(string _value, uint256 indexed _id);

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, string calldata uri, bool initiallyFrozen) public payable returns (uint256) {
        require(msg.value == _price, "Ether amount sent is not correct");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        frozen[tokenId] = initiallyFrozen;
        emit TokenMinted(tokenId, uri, to, initiallyFrozen);

        return tokenId;
    }

    function updatePrice(uint256 amount) public onlyOwner {
        _price = amount;
    }

    function updateTokenURI(uint256 tokenId, string calldata _tokenURI) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        require(frozen[tokenId] == false, "is leider final!");

        if (_tokenURI.length == 0) {
            revert("muddu string geben");
        }
        
        _setTokenURI(_tokenURI);
        emit TokenURIUpdated(tokenId, _tokenURI);
    }

    function freeze(uint256 tokenId) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        frozen[tokenId] = true;
        emit PermanentURI(this.tokenURI(tokenId), tokenId);
    }

    // Withdraw ETH from contract
    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

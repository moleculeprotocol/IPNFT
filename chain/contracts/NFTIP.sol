//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IPNFT is ERC721URIStorage, Ownable {
    // Events
    event TokenURIChanged(uint256 tokenId, string indexed newURI);

    //calling constructor from this contract plus ERC721 constructor
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function setTokenURI(uint256 tokenId, string memory _tokenURI)
        public
        onlyOwner
    {
        _setTokenURI(tokenId, _tokenURI);
        emit TokenURIChanged(tokenId, _tokenURI);
    }

    // default mint is minting with tokenURI
    function mint(
        address to,
        uint256 _tokenId,
        string memory _tokenURI
    ) public returns (bool) {
        _safeMint(to, _tokenId);
        setTokenURI(_tokenId, _tokenURI);

        return true;
    }

    // there is an option to mint the NFT without the tokenURI if needed too
    function mintWithoutTokenURI(address to, uint256 _tokenId)
        external
        onlyOwner
    {
        _safeMint(to, _tokenId);
    }

    function transfer(
        address from,
        address to,
        uint256 _tokenId
    ) public {
        safeTransferFrom(from, to, _tokenId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

    Counters.Counter private _reservationCounter;

    struct Reservation {
        address reserver;
        string tokenURI;
    }

    uint256 private _price = 0 ether;
    mapping(uint256 => bool) public frozen;

    mapping(uint256 => address) private _reserved;
    mapping(uint256 => Reservation) public reservations;

    event TokenURIUpdated(uint256 tokenId, string tokenURI);
    event TokenMinted(uint256 tokenId, string tokenURI, address owner);
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

    function updatePrice(uint256 amount) public onlyOwner {
        _price = amount;
    }

    function freeze(uint256 tokenId) external {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        frozen[tokenId] = true;
        emit PermanentURI(this.tokenURI(tokenId), tokenId);
    }

    function mintReservation(address to, uint256 reservationId)
        public
        payable
        returns (uint256 tokenId)
    {
        require(msg.value == _price, "Ether amount sent is not correct");
        require(
            reservations[reservationId].reserver == _msgSender(),
            "IP NFT: caller is not reserver"
        );

        _safeMint(to, reservationId);
        _setTokenURI(reservationId, reservations[reservationId].tokenURI);

        emit PermanentURI(reservations[reservationId].tokenURI, reservationId);
        emit TokenMinted(
            reservationId,
            reservations[reservationId].tokenURI,
            to
        );

        delete reservations[reservationId];

        return reservationId;
    }

    function reserve(string memory _tokenURI) public returns (uint256) {
        uint256 tokenId = _reservationCounter.current();
        _reservationCounter.increment();
        reservations[tokenId] = Reservation({
            reserver: _msgSender(),
            tokenURI: _tokenURI
        });

        return tokenId;
    }

    function updateTokenURI(uint256 reservationId, string calldata _tokenURI)
        external
    {
        require(
            reservations[reservationId].reserver == _msgSender(),
            "Reservation not valid or not owned by you"
        );

        //require(frozen[tokenId] == false, "Metadata is frozen");
        //_setTokenURI(tokenId, _tokenURI);
        reservations[reservationId].tokenURI = _tokenURI;
        emit TokenURIUpdated(reservationId, _tokenURI);
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

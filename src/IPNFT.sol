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

    mapping(uint256 => Reservation) public reservations;

    event Reserved(
        address indexed reserver,
        uint256 indexed reservationId
    );
    event ReservationURIUpdated(
        string tokenURI,
        address indexed reserver,
        uint256 indexed reservationId
    );
    event TokenMinted(
        string tokenURI,
        address indexed owner,
        uint256 indexed tokenId
    );

    /// @dev https://docs.opensea.io/docs/metadata-standards#freezing-metadata
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
            reservations[reservationId].tokenURI,
            to,
            reservationId
        );

        delete reservations[reservationId];

        return reservationId;
    }

    function reserve() public returns (uint256) {
        uint256 reservationId = _reservationCounter.current();
        _reservationCounter.increment();
        reservations[reservationId] = Reservation({
            reserver: _msgSender(),
            tokenURI: ""
        });
        emit Reserved(_msgSender(), reservationId);
        return reservationId;
    }

    function updateReservationURI(uint256 reservationId, string calldata _tokenURI)
        external
    {
        require(
            reservations[reservationId].reserver == _msgSender(),
            "Reservation not valid or not owned by you"
        );

        reservations[reservationId].tokenURI = _tokenURI;
        emit ReservationURIUpdated(_tokenURI, _msgSender(), reservationId);
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

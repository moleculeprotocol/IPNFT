// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

/*
 ______ _______         __    __ ________ ________
|      \       \       |  \  |  \        \        \
 \▓▓▓▓▓▓ ▓▓▓▓▓▓▓\      | ▓▓\ | ▓▓ ▓▓▓▓▓▓▓▓\▓▓▓▓▓▓▓▓
  | ▓▓ | ▓▓__/ ▓▓______| ▓▓▓\| ▓▓ ▓▓__      | ▓▓
  | ▓▓ | ▓▓    ▓▓      \ ▓▓▓▓\ ▓▓ ▓▓  \     | ▓▓
  | ▓▓ | ▓▓▓▓▓▓▓ \▓▓▓▓▓▓ ▓▓\▓▓ ▓▓ ▓▓▓▓▓     | ▓▓
 _| ▓▓_| ▓▓            | ▓▓ \▓▓▓▓ ▓▓        | ▓▓
|   ▓▓ \ ▓▓            | ▓▓  \▓▓▓ ▓▓        | ▓▓
 \▓▓▓▓▓▓\▓▓             \▓▓   \▓▓\▓▓         \▓▓

*/

contract IPNFT is
    ERC1155,
    Ownable,
    Pausable,
    ERC1155Burnable,
    ERC1155Supply,
    ERC1155URIStorage
{
    using Counters for Counters.Counter;

    Counters.Counter private _reservationCounter;

    struct Reservation {
        address reserver;
        string tokenURI;
    }

    uint256 public mintPrice = 0 ether;

    mapping(uint256 => Reservation) public reservations;

    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationURIUpdated(
        string tokenURI,
        address indexed reserver,
        uint256 indexed reservationId
    );
    event TokenMinted(
        string tokenURI,
        address indexed owner,
        uint256 indexed tokenId,
        uint256 shares
    );

    /// @dev https://docs.opensea.io/docs/metadata-standards#freezing-metadata
    event PermanentURI(string _value, uint256 indexed _id);

    constructor() ERC1155("") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updateMintPrice(uint256 amount) public onlyOwner {
        mintPrice = amount;
    }

    // This is how a direct mint could look like for IP-NFTs that don't need encrypted legal contracts.
    // The Question is how useful this is, after all the legal contract might still require
    // a hard reference to the IP-NFT tokenId. For this function you wouldn't get that
    // tokenId until after the mint of course.
    function directMint(address to, string memory tokenURI)
        public
        payable
        returns (uint256 tokenId)
    {
        require(msg.value >= mintPrice, "Ether amount sent is too small");

        uint256 newTokenId = _reservationCounter.current();
        _reservationCounter.increment();

        // Given that we're not super confident about the metadata being "final" yet,
        // I don't think we should set the permanent URI yet.
        emit PermanentURI(tokenURI, newTokenId);

        emit TokenMinted(tokenURI, to, newTokenId, 1);

        _mint(to, newTokenId, 1, "");
        _setURI(newTokenId, tokenURI);

        return tokenId;
    }

    function mintReservation(address to, uint256 reservationId)
        public
        payable
        returns (uint256 tokenId)
    {
        return
            mintReservation(
                to,
                reservationId,
                reservations[reservationId].tokenURI
            );
    }

    function mintReservation(
        address to,
        uint256 reservationId,
        string memory tokenURI
    ) public payable returns (uint256 tokenId) {
        require(msg.value >= mintPrice, "Ether amount sent is too small");
        require(
            reservations[reservationId].reserver == _msgSender(),
            "IP-NFT: caller is not reserver"
        );

        // Given that we're not super confident about the metadata being "final" yet,
        // I don't think we should set the permanent URI yet.
        emit PermanentURI(tokenURI, reservationId);

        emit TokenMinted(tokenURI, to, reservationId, 1);

        delete reservations[reservationId];

        _mint(to, reservationId, 1, "");
        _setURI(reservationId, tokenURI);

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

    function updateReservationURI(
        uint256 reservationId,
        string calldata _tokenURI
    ) external {
        require(
            reservations[reservationId].reserver == _msgSender(),
            "IP-NFT: Reservation not valid or not owned by you"
        );

        reservations[reservationId].tokenURI = _tokenURI;
        emit ReservationURIUpdated(_tokenURI, _msgSender(), reservationId);
    }

    function increaseShares(
        uint256 tokenId,
        uint256 shares,
        address to
    ) public {
        require(shares > 0, "IP-NFT: shares amount must be greater than 0");
        require(totalSupply(tokenId) == 1, "IP-NFT: shares already minted");
        require(balanceOf(_msgSender(), tokenId) == 1, "IP-NFT: not owner");

        _mint(to, tokenId, shares, "");
    }

    // Withdraw ETH from contract
    function withdrawAll() public payable onlyOwner {
        require(
            payable(msg.sender).send(address(this).balance),
            "Not authorized"
        );
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155, ERC1155URIStorage)
        returns (string memory)
    {
        return super.uri(tokenId);
    }
}

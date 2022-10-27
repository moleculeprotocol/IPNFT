// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

contract IPNFT_ERC1155 is
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

    uint256 public price = 0 ether;

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
        uint256 sharesAmount
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

    function updatePrice(uint256 amount) public onlyOwner {
        price = amount;
    }

    function mintReservation(
        address to,
        uint256 reservationId,
        uint256 sharesAmount
    ) public payable returns (uint256 tokenId) {
        require(msg.value == price, "Ether amount sent is not correct");
        require(
            reservations[reservationId].reserver == _msgSender(),
            "IP-NFT: caller is not reserver"
        );

        _mint(to, reservationId, sharesAmount, "");
        _setURI(reservationId, reservations[reservationId].tokenURI);

        // Given that we're not super confident about the metadata being "final" yet,
        // I don't think we should set the permanent URI yet.
        emit PermanentURI(reservations[reservationId].tokenURI, reservationId);

        emit TokenMinted(
            reservations[reservationId].tokenURI,
            to,
            reservationId,
            sharesAmount
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

    function updateReservationURI(
        uint256 reservationId,
        string calldata _tokenURI
    ) external {
        require(
            reservations[reservationId].reserver == _msgSender(),
            "Reservation not valid or not owned by you"
        );

        reservations[reservationId].tokenURI = _tokenURI;
        emit ReservationURIUpdated(_tokenURI, _msgSender(), reservationId);
    }

    function increaseShares(
        uint256 tokenId,
        uint256 sharesAmount,
        address to
    ) public {
        require(
            sharesAmount > 0,
            "IP-NFT: shares amount must be greater than 0"
        );
        require(totalSupply(tokenId) == 1, "IP-NFT: shares already minted");
        require(balanceOf(_msgSender(), tokenId) == 1, "IP-NFT: not owner");

        _mint(to, tokenId, sharesAmount, "");
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

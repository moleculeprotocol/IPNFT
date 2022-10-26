// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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
        uint256 indexed tokenId
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

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function mintReservation(address to, uint256 reservationId)
        public
        payable
        returns (uint256 tokenId)
    {
        require(msg.value == price, "Ether amount sent is not correct");
        require(
            reservations[reservationId].reserver == _msgSender(),
            "IP NFT: caller is not reserver"
        );

        _mint(to, reservationId, 1, "");
        _setURI(reservationId, reservations[reservationId].tokenURI);

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

    // Withdraw ETH from contract
    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
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

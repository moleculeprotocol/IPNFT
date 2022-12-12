// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ERC1155URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { ERC1155BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Mintpass } from "./Mintpass.sol";
import { IReservable } from "./IReservable.sol";

/*
 ______ _______         __    __ ________ ________
|      \       \       |  \  |  \        \        \
 \▓▓▓▓▓▓ ▓▓▓▓▓▓▓\      | ▓▓\ | ▓▓ ▓▓▓▓▓▓▓▓\▓▓▓▓▓▓▓▓
  | ▓▓ | ▓▓__/ ▓▓______| ▓▓▓\| ▓▓ ▓▓__      | ▓▓
  | ▓▓ | ▓▓    ▓▓      \ ▓▓▓▓\ ▓▓ ▓▓  \     | ▓▓
  | ▓▓ | ▓▓▓▓▓▓▓ \▓▓▓▓▓▓ ▓▓\▓▓ ▓▓ ▓▓▓▓▓     | ▓▓
 _| ▓▓_| ▓▓            | ▓▓ \▓▓▓▓ ▓▓        | ▓▓
|   ▓▓ \ ▓▓            | ▓▓  \▓▓▓ ▓▓        | ▓▓
 \▓▓▓▓▓▓\▓▓             \▓▓   \▓▓\▓▓         \▓▓*/

contract IPNFT is
    IReservable,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable,
    ERC1155URIStorageUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Reservation {
        address reserver;
        string tokenURI;
    }

    CountersUpgradeable.Counter private _reservationCounter;
    mapping(uint256 => Reservation) public reservations;

    /// @notice Current version of the contract
    uint16 internal _version;

    /// @notice external mintpass contract
    Mintpass mintpass;

    /**
     *
     * EVENTS
     *
     */

    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string tokenURI, uint256 indexed reservationId);
    event IPNFTMinted(address indexed minter, uint256 indexed tokenId, string tokenURI);

    /// @dev https://docs.opensea.io/docs/metadata-standards#freezing-metadata
    event PermanentURI(string _value, uint256 indexed _id);

    /**
     *
     * ERRORS
     *
     */

    error EmptyInput();
    error InvalidInput();
    error NeedsMintpass();
    error NotOwningReservation(uint256 id);
    error ToZeroAddress();
    error NonExistentSlot(uint256 id);
    error NotApprovedOrOwner();
    error NotAvailInV2();

    /**
     *
     * DEPLOY
     *
     */

    /// @notice Contract constructor logic
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Contract initialization logic
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC1155_init("");
        __ERC1155Burnable_init();
        __ERC1155URIStorage_init();
        __ERC1155Supply_init();

        _reservationCounter.increment(); //start at 1.
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     *
     * PUBLIC
     *
     */

    /// @notice sets the address of the Mintpass contract
    function setMintpassContract(address mintpass_) public onlyOwner {
        if (mintpass_ == address(0)) {
            revert ToZeroAddress();
        }
        mintpass = Mintpass(mintpass_);
    }

    function reserve() public returns (uint256) {
        if (!(mintpass.balanceOf(_msgSender()) > 0)) {
            revert NeedsMintpass();
        }

        uint256 reservationId = _reservationCounter.current();
        _reservationCounter.increment();
        reservations[reservationId] = Reservation({reserver: _msgSender(), tokenURI: ""});
        emit Reserved(_msgSender(), reservationId);
        return reservationId;
    }

    function updateReservation(uint256 reservationId, string calldata _tokenURI) external {
        if (reservations[reservationId].reserver != _msgSender()) {
            revert NotOwningReservation(reservationId);
        }

        reservations[reservationId].tokenURI = _tokenURI;
        emit ReservationUpdated(_tokenURI, reservationId);
    }

    function mintReservation(address to, uint256 mintPassId, uint256 reservationId) public returns (uint256) {
        return mintReservation(to, reservationId, mintPassId, reservations[reservationId].tokenURI);
    }

    function mintReservation(address to, uint256 reservationId, uint256 mintPassId, string memory tokenURI) public override returns (uint256) {
        if (reservations[reservationId].reserver != _msgSender()) {
            revert NotOwningReservation(reservationId);
        }

        mintpass.authorizeMint(_msgSender(), mintPassId);

        //todo: emit this, once we decided if we're sure that this one is going to be final.
        //emit PermanentURI(tokenURI, reservationId);
        delete reservations[reservationId];
        mintpass.redeem(mintPassId);

        _mint(to, reservationId, 1, "");
        _setURI(reservationId, tokenURI);

        emit IPNFTMinted(to, reservationId, tokenURI);
        return reservationId;
    }

    // This is how a direct mint could look like for IP-NFTs that don't need encrypted legal contracts.
    // The Question is how useful this is, after all the legal contract might still require
    // a hard reference to the IP-NFT tokenId. For this function you wouldn't get that
    // tokenId until after the mint of course.
    // function directMint(address to, string memory tokenURI) public payable returns (uint256 tokenId) {
    //     require(msg.value >= mintPrice, "Ether amount sent is too small");

    //     uint256 newTokenId = _reservationCounter.current();
    //     _reservationCounter.increment();

    //     // Given that we're not super confident about the metadata being "final" yet,
    //     // I don't think we should set the permanent URI yet.
    //     emit PermanentURI(tokenURI, newTokenId);

    //     emit TokenMinted(tokenURI, to, newTokenId, 1);

    //     _mint(to, newTokenId, 1, "");
    //     _setURI(newTokenId, tokenURI);

    //     return tokenId;
    // }

    // function increaseShares(uint256 tokenId, uint256 shares, address to) public {
    //     require(shares > 0, "IP-NFT: shares amount must be greater than 0");
    //     require(totalSupply(tokenId) == 1, "IP-NFT: shares already minted");
    //     require(balanceOf(_msgSender(), tokenId) == 1, "IP-NFT: not owner");

    //     _mint(to, tokenId, shares, "");
    // }

    // Withdraw ETH from contract
    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance), "transfer failed");
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override (ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function uri(uint256 tokenId) public view virtual override (ERC1155Upgradeable, ERC1155URIStorageUpgradeable) returns (string memory) {
        return ERC1155URIStorageUpgradeable.uri(tokenId);
    }

    /// @notice upgrade authorization logic
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    {
        //empty block
    }
}

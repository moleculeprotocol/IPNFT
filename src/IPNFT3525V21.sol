// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "hypercerts/ERC3525SlotEnumerableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import { IPNFT, Reservation } from "./Structs.sol";
import { IReservable } from "./IReservable.sol";
import { Mintpass } from "./Mintpass.sol";
import { IIPNFTMetadata } from "./IPNFTMetadata.sol";

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

/// @title minting logic
/// @notice Contains functions and events to initialize and issue an ipnft
/// @author contains code of bitbeckers, mr_bluesky
contract IPNFT3525V21 is
    Initializable,
    ERC3525SlotEnumerableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IReservable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _reservationCounter;

    /// @notice Contract name
    string public constant NAME = "IP-NFT V2.1";
    /// @notice Token symbol
    string public constant SYMBOL = "IPNFT";
    /// @notice Token value decimals
    uint8 public constant DECIMALS = 0;

    uint64 public constant DEFAULT_VALUE = 1_000_000;

    /// @notice Current version of the contract
    uint16 internal _version;

    /// @notice external metadata contract
    IIPNFTMetadata _metadataGenerator;

    /// @notice external mintpass contract
    Mintpass mintpass;

    mapping(uint256 => IPNFT) internal _ipnfts;
    mapping(uint256 => Reservation) public _reservations;

    /**
     *
     * EVENTS
     *
     */

    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string name, uint256 indexed reservationId);

    /// @notice Emitted when an NFT is minted
    /// @param minter the minter's address
    /// @param tokenId the minted token (slot) id
    event IPNFTMinted(address indexed minter, uint256 indexed tokenId);

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
        __ERC3525Upgradeable_init();

        _reservationCounter.increment(); //start at 1.
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

    function setMetadataGenerator(IIPNFTMetadata metadataGenerator_) external onlyOwner {
        if (address(metadataGenerator_) == address(0)) {
            revert ToZeroAddress();
        }
        _metadataGenerator = metadataGenerator_;
    }

    function reserve() public returns (uint256) {
        if (!(mintpass.balanceOf(_msgSender()) > 0)) {
            revert NeedsMintpass();
        }

        IPNFT memory reservation;

        uint256 reservationId = _reservationCounter.current();
        _reservationCounter.increment();
        _reservations[reservationId] = Reservation({reserver: _msgSender(), ipnft: reservation});

        emit Reserved(_msgSender(), reservationId);
        return reservationId;
    }

    function updateReservation(uint256 reservationId, bytes calldata newMetadata) external {
        if (_reservations[reservationId].reserver != _msgSender()) {
            revert NotOwningReservation(reservationId);
        }
        _reservations[reservationId].ipnft = _parseData(newMetadata);

        emit ReservationUpdated(_reservations[reservationId].ipnft.name, reservationId);
    }

    /// @notice Issues a new IPNFT on a new slot, mints DEFAULT_VALUE to the first owner
    /// @param to  Account the new IPNFT is issued to
    /// @param reservationId the reservation id to use
    /// @param mintPassId the id of a mint pass that's burnt during the mint.
    /// @param finalMetadata optional an encoded payload
    function mintReservation(address to, uint256 reservationId, uint256 mintPassId, bytes memory finalMetadata)
        external
        returns (uint256 slotId)
    {
        if (_reservations[reservationId].reserver != _msgSender()) {
            revert NotOwningReservation(reservationId);
        }

        mintpass.authorizeMint(_msgSender(), mintPassId);

        IPNFT memory ipnft = finalMetadata.length > 0 ? _parseData(finalMetadata) : _reservations[reservationId].ipnft;
        ipnft.totalUnits = DEFAULT_VALUE;
        ipnft.version = uint16(0);
        ipnft.exists = true;
        ipnft.minter = _msgSender();

        //todo: emit this, once we decided if we're sure that this one is going to be final.
        //emit PermanentURI(tokenURI, reservationId);

        emit IPNFTMinted(to, reservationId);

        delete _reservations[reservationId];
        _ipnfts[reservationId] = ipnft;

        /// @see _beforeValueTransfer: it creates slot with that reservation id
        _mintValue(to, reservationId, DEFAULT_VALUE);

        mintpass.burn(mintPassId);

        return reservationId;
    }

    function split(uint256 tokenId, uint256[] calldata amounts) public {
        if (!_exists(tokenId)) revert NonExistentToken(tokenId);

        if (ownerOf(tokenId) != _msgSender()) {
            revert NotApprovedOrOwner();
        }

        uint256 total;

        uint256 amountsLength = amounts.length;
        if (amountsLength == 1) revert AlreadyMinted(tokenId);

        for (uint256 i; i < amountsLength; i++) {
            total += amounts[i];
        }

        if (total > balanceOf(tokenId) || total < balanceOf(tokenId)) {
            revert InvalidInput();
        }

        for (uint256 i = 1; i < amountsLength; i++) {
            _splitValue(tokenId, amounts[i]);
        }
    }

    function merge(uint256[] memory tokenIds) public {
        uint256 len = tokenIds.length;
        uint256 targetTokenId = tokenIds[len - 1];
        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = tokenIds[i];
            if (tokenId != targetTokenId) {
                _mergeValue(tokenId, targetTokenId);
                _burn(tokenId);
            }
        }
    }

    /// @notice gets the current version of the contract
    function version() public view virtual returns (uint256) {
        return _version;
    }

    /// @notice Update the contract version number
    function updateVersion() external onlyOwner {
        _version += 1;
    }

    /// @notice Returns a flag indicating if the contract supports the specified interface
    /// @param interfaceId Id of the interface
    /// @return true, if the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override (ERC3525SlotEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function name() public pure override returns (string memory) {
        return NAME;
    }

    function symbol() public pure override returns (string memory) {
        return SYMBOL;
    }

    function valueDecimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    function slotURI(uint256 slotId) public view override returns (string memory) {
        if (!_ipnfts[slotId].exists) {
            revert NonExistentSlot(slotId);
        }
        IPNFT memory slot = _ipnfts[slotId];
        return _metadataGenerator.generateSlotURI(slot);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 slotId = slotOf(tokenId);
        if (!_ipnfts[slotId].exists) {
            revert NonExistentSlot(slotId);
        }
        IPNFT memory token = _ipnfts[slotId];
        uint256 balance = balanceOf(tokenId);
        return _metadataGenerator.generateTokenURI(token, tokenId, slotId, balance);
    }

    function contractURI() public view override returns (string memory) {
        return _metadataGenerator.generateContractURI();
    }

    function burn(uint256 tokenId_) public {
        uint256 ipnftId = slotOf(tokenId_);
        IPNFT storage ipnft = _ipnfts[ipnftId];
        if (msg.sender != ipnft.minter) {
            revert NotApprovedOrOwner();
        }

        if (balanceOf(tokenId_) != ipnft.totalUnits) {
            revert InsufficientBalance(ipnft.totalUnits, balanceOf(tokenId_));
        }

        ipnft.exists = false;
        _burn(tokenId_);
    }

    /**
     *
     * INTERNAL
     *
     */

    /* solhint-enable code-complexity */

    /// @notice Parse bytes for basic metadata
    /// @param newMetadata bytes name, description and reference urls
    /// @dev This function is overridable in order to support future schema changes
    /// @return ipnft IPNFT
    function _parseData(bytes memory newMetadata) internal pure virtual returns (IPNFT memory ipnft) {
        if (newMetadata.length == 0) {
            revert EmptyInput();
        }

        (
            string memory name_,
            string memory description_,
            string memory imageUrl_,
            string memory agreementUrl_,
            string memory projectDetailsUrl_
        ) = abi.decode(newMetadata, (string, string, string, string, string));

        ipnft.name = name_;
        ipnft.description = description_;
        ipnft.imageUrl = imageUrl_;
        ipnft.agreementUrl = agreementUrl_;
        ipnft.projectDetailsUrl = projectDetailsUrl_;

        return ipnft;
    }

    /// @notice upgrade authorization logic
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view override onlyOwner {
        //empty block
    }

    function _msgSender() internal view override (ContextUpgradeable, ERC3525Upgradeable) returns (address sender) {
        return msg.sender;
    }
}

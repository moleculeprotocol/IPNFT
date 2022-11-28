// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "hypercerts/ERC3525SlotEnumerableUpgradeable.sol";
import "hypercerts/interfaces/IHyperCertMetadata.sol";
import "hypercerts/utils/ArraysUpgradeable.sol";
import "hypercerts/utils/StringsExtensions.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";

import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import { Mintpass } from "./Mintpass.sol";

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

error EmptyInput();
error InvalidInput();

/// @title minting logic
/// @notice Contains functions and events to initialize and issue an ipnft
/// @author contains code of bitbeckers, mr_bluesky
contract IPNFT3525V2 is Initializable, ERC3525SlotEnumerableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using ArraysUpgradeable for uint64[];
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _reservationCounter;

    /// @notice Contract name
    string public constant NAME = "IP-NFT V2";
    /// @notice Token symbol
    string public constant SYMBOL = "IPNFT";
    /// @notice Token value decimals
    uint8 public constant DECIMALS = 0;
    /// @notice User role required in order to upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint64 public constant DEFAULT_VALUE = 1_000_000;

    /// @notice Current version of the contract
    uint16 internal _version;

    /// @notice external metadata contract
    //IIPNFTMetadata internal _metadata;

    struct IPNFT {
        uint256 totalUnits;
        uint16 version;
        bool exists;
        string name;
        string tokenURI;
        address minter;
    }

    struct Reservation {
        address reserver;
        string name;
        string tokenURI;
    }

    mapping(uint256 => IPNFT) internal _ipnfts;
    mapping(uint256 => Reservation) public _reservations;

    address mintPassContract;

    /**
     *
     * EVENTS
     *
     */

    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event ReservationUpdated(string tokenURI, uint256 indexed reservationId);

    /// @notice Emitted when an NFT is minted
    /// @param tokenURI the uri containing the ip metadata
    /// @param minter the minter's address
    /// @param tokenId the minted token (slot) id
    event IPNFTMinted(string tokenURI, address indexed minter, uint256 indexed tokenId);

    /// @dev https://docs.opensea.io/docs/metadata-standards#freezing-metadata
    event PermanentURI(string _value, uint256 indexed _id);

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
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC3525Upgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _reservationCounter.increment(); //start at 1.
    }

    /**
     *
     * PUBLIC
     *
     */

    function reserve() public returns (uint256) {
        Mintpass mintpass = Mintpass(mintPassContract);
        require(mintpass.balanceOf(_msgSender()) > 0, "IPNFT: You need to own a mintpass to mint an IPNFT");

        uint256 reservationId = _reservationCounter.current();
        _reservationCounter.increment();
        _reservations[reservationId] = Reservation({reserver: _msgSender(), name: "", tokenURI: ""});
        emit Reserved(_msgSender(), reservationId);
        return reservationId;
    }

    function updateReservation(
        uint256 reservationId,
        //todo: if this gets longer, use abiencoded bytes.
        string calldata _name,
        string calldata _tokenURI
    ) external {
        require(_reservations[reservationId].reserver == _msgSender(), "IP-NFT: caller is not reserver");
        if (bytes(_name).length > 0) {
            _reservations[reservationId].name = _name;
        }
        if (bytes(_tokenURI).length > 0) {
            _reservations[reservationId].tokenURI = _tokenURI;
        }
        emit ReservationUpdated(_tokenURI, reservationId);
    }

    function mintReservation(address to, uint256 reservationId, uint256 mintPassId)
        public
        payable
        returns (uint256 tokenId)
    {
        return mintReservation(to, reservationId, _reservations[reservationId].tokenURI, mintPassId);
    }

    /// @notice Issues a new IPNFT on a new slot, mints DEFAULT_VALUE to the first owner
    /// @param to  Account the new IPNFT is issued to
    /// @param reservationId the reservation id to use
    function mintReservation(address to, uint256 reservationId, string memory _tokenURI, uint256 mintPassId)
        public
        payable
        returns (uint256 slotId)
    {
        Mintpass mintpass = Mintpass(mintPassContract);

        require(_reservations[reservationId].reserver == _msgSender(), "IP-NFT: caller is not reserver");

        require(mintpass.ownerOf(mintPassId) == _msgSender(), "IPNFT: You don't own that mintpass");

        require(mintpass.isValid(mintPassId), "IPNFT: Mintpass was revoked");

        IPNFT memory ipnft = IPNFT({
            totalUnits: DEFAULT_VALUE,
            version: uint16(0),
            exists: true,
            name: _reservations[reservationId].name,
            tokenURI: _tokenURI,
            minter: _msgSender()
        });

        _authorizeMint(to, ipnft);

        //todo: emit this, once we decided if we're sure that this one is going to be final.
        //emit PermanentURI(tokenURI, reservationId);

        emit IPNFTMinted(_tokenURI, to, reservationId);

        delete _reservations[reservationId];
        _ipnfts[reservationId] = ipnft;

        /// @see _beforeValueTransfer: it creates slot with that reservation id
        _mintValue(to, reservationId, DEFAULT_VALUE);

        mintpass.burn(mintPassId);

        return reservationId;
    }

    /// @notice sets the address of the Mintpass contract
    function setMintpassContract(address newContract) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "IP-NFT: caller is not admin");
        mintPassContract = newContract;
    }

    /// @notice gets the current version of the contract
    function version() public view virtual returns (uint256) {
        return _version;
    }

    /// @notice Update the contract version number
    /// @notice Only allowed for member of UPGRADER_ROLE
    function updateVersion() external onlyRole(UPGRADER_ROLE) {
        _version += 1;
    }

    /// @notice Returns a flag indicating if the contract supports the specified interface
    /// @param interfaceId Id of the interface
    /// @return true, if the interface is supported
    //todo: don't return ERC3525 related interfaces
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override (ERC3525SlotEnumerableUpgradeable, AccessControlUpgradeable)
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

    function slotURI(uint256 slotId_) public view override returns (string memory) {
        if (!_ipnfts[slotId_].exists) {
            revert NonExistentSlot(slotId_);
        }
        IPNFT memory slot = _ipnfts[slotId_];

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64Upgradeable.encode(
                    abi.encodePacked('{"name":"', slot.name, '","external_url":"', slot.tokenURI, '"}')
                )
            )
        );
    }

    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        uint256 slotId = slotOf(tokenId_);

        return slotURI(slotId);
    }

    //todo: contract metadata
    function contractURI() public pure override returns (string memory) {
        return "contract uri";
        //return _metadata.generateContractURI();
    }

    function burn(uint256 tokenId_) public {
        uint256 ipnftId = slotOf(tokenId_);
        IPNFT storage ipnft = _ipnfts[ipnftId];

        //todo this is a leftover of the fractional impl. Leave it for additional security.
        if (balanceOf(tokenId_) != ipnft.totalUnits) {
            revert InsufficientBalance(ipnft.totalUnits, balanceOf(tokenId_));
        }

        ipnft.exists = false;
        _burn(tokenId_);
    }

    /**
     *
     * DISABLE value transfers and splits in V2
     *
     */

    function transferFrom(uint256 fromTokenId_, address to_, uint256 value_)
        public
        payable
        virtual
        override
        returns (uint256)
    {
        revert("not available in V2");
    }

    function transferFrom(uint256 fromTokenId_, uint256 toTokenId_, uint256 value_) public payable virtual override {
        revert("not available in V2");
    }

    function approve(uint256 tokenId_, address to_, uint256 value_) external payable virtual override {
        revert("not available in V2");
    }

    /**
     *
     * INTERNAL
     *
     */

    /// @notice upgrade authorization logic
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        view
        override
        onlyRole(UPGRADER_ROLE) // solhint-disable-next-line no-empty-blocks
    {
        //empty block
    }

    /// @notice Pre-mint validation checks
    /// @param account Destination address for the mint
    /// @param ipnft IPNFT data
    /* solhint-disable code-complexity */

    function _authorizeMint(address account, IPNFT memory ipnft) internal view virtual {
        if (account == address(0)) {
            revert ToZeroAddress();
        }
    }

    function _msgSender() internal view override (ContextUpgradeable, ERC3525Upgradeable) returns (address sender) {
        return msg.sender;
    }

    // function setMetadataGenerator(address metadataGenerator)
    //     external
    //     onlyRole(UPGRADER_ROLE)
    // {
    //     if (metadataGenerator == address(0)) {
    //         revert ToZeroAddress();
    //     }
    //     _metadata = IHyperCertMetadata(metadataGenerator);
    // }
}

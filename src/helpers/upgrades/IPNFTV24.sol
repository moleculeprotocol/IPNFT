// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { ERC721BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import { ERC721URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAuthorizeMints } from "../../IAuthorizeMints.sol";
import { IReservable } from "../../IReservable.sol";

/*
 ▄▄▄ ▄▄▄▄▄▄▄ ▄▄    ▄ ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄   ▄▄ ▄▄▄▄▄▄▄ ▄   ▄▄▄ 
█   █       █  █  █ █       █       █  █ █  █       █ █ █   █
█   █    ▄  █   █▄█ █    ▄▄▄█▄     ▄█  █▄█  █▄▄▄▄   █ █▄█   █
█   █   █▄█ █       █   █▄▄▄  █   █ █       █▄▄▄▄█  █       █
█   █    ▄▄▄█  ▄    █    ▄▄▄█ █   █ █       █ ▄▄▄▄▄▄█▄▄▄    █
█   █   █   █ █ █   █   █     █   █  █     ██ █▄▄▄▄▄    █   █
█▄▄▄█▄▄▄█   █▄█  █▄▄█▄▄▄█     █▄▄▄█   █▄▄▄█ █▄▄▄▄▄▄▄█   █▄▄▄█
 */

/// @title IPNFTV2.4 Demo for Testing Upgrades
/// @author molecule.to
/// @notice Demo contract to test upgrades. Don't use like this
/// @dev Don't use this for anything other than testing.
contract IPNFTV24 is ERC721URIStorageUpgradeable, ERC721BurnableUpgradeable, IReservable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _reservationCounter;

    /// @notice by reserving a mint an user captures a new token id
    mapping(uint256 => address) public reservations;

    /// @notice Current version of the contract
    uint16 internal _version;

    /// @notice e.g. a mintpass contract
    IAuthorizeMints mintAuthorizer;

    mapping(uint256 => mapping(address => uint256)) internal readAllowances;

    uint256 constant SYMBOLIC_MINT_FEE = 0.001 ether;

    /// @notice an IPNFT's base symbol, to be determined by the minter / owner. E.g. BIO-00001
    mapping(uint256 => string) public symbol;

    /// @notice musnt't take the minting fee property gap
    string public aNewProperty;

    /*
     *
     * EVENTS
     *
     */

    event Reserved(address indexed reserver, uint256 indexed reservationId);
    event IPNFTMinted(address indexed owner, uint256 indexed tokenId, string tokenURI, string symbol);
    event ReadAccessGranted(uint256 indexed tokenId, address indexed reader, uint256 until);

    // A NEW EVENT FOR UPDATES
    event SymbolUpdated(uint256 indexed tokenId, string symbol);

    /*
     *
     * ERRORS
     *
     */

    error NotOwningReservation(uint256 id);
    error ToZeroAddress();
    error NeedsMintpass();
    error InsufficientBalance();
    error MintingFeeTooLow();

    /// @notice Contract constructor logic
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Contract initialization logic
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();
        __ERC721_init("IPNFT", "IPNFT");
        _reservationCounter.increment(); //start at 1.
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function reinit() public onlyOwner reinitializer(2) {
        aNewProperty = "some property";
    }

    /*
     *
     * PUBLIC
     *
     */

    function setAuthorizer(address authorizer_) public onlyOwner {
        if (authorizer_ == address(0)) {
            revert ToZeroAddress();
        }
        mintAuthorizer = IAuthorizeMints(authorizer_);
    }

    /// @notice reserves a new token id. Checks that the caller is authorized, according to the current implementation of IAuthorizeMints.
    function reserve() public whenNotPaused returns (uint256) {
        if (!mintAuthorizer.authorizeReservation(_msgSender())) {
            revert NeedsMintpass();
        }

        uint256 reservationId = _reservationCounter.current();
        _reservationCounter.increment();
        reservations[reservationId] = _msgSender();
        emit Reserved(_msgSender(), reservationId);
        return reservationId;
    }

    /**
     * @notice deprecated: the old interface without a symbol.
     */
    function mintReservation(address to, uint256 reservationId, uint256 mintPassId, string memory _tokenURI)
        public
        payable
        whenNotPaused
        returns (uint256)
    {
        return mintReservation(to, reservationId, mintPassId, _tokenURI, "");
    }

    /**
     * @notice mints an IPNFT with `tokenURI` as source of metadata. Invalidates the reservation. Redeems `mintpassId` on the authorizer contract
     * @notice We are charging a nominal fee to symbolically represent the transfer of ownership rights, for a price of .001 ETH (<$2USD at current prices). This helps the ensure the protocol is affordable to almost all projects, but discourages frivolous IP-NFT minting.
     *
     * @param to address the recipient of the NFT
     * @param reservationId the reserved token id that has been reserved with `reserve()`
     * @param mintPassId an id that's handed over to the `IAuthorizeMints` interface
     * @param _tokenURI a location that resolves to a valid IP-NFT metadata structure
     * @param _symbol a symbol that represents the IPNFT's derivatives. Can be changed by the owner
     */
    function mintReservation(address to, uint256 reservationId, uint256 mintPassId, string memory _tokenURI, string memory _symbol)
        public
        payable
        override
        whenNotPaused
        returns (uint256)
    {
        if (reservations[reservationId] != _msgSender()) {
            revert NotOwningReservation(reservationId);
        }

        if (!mintAuthorizer.authorizeMint(_msgSender(), to, abi.encode(mintPassId))) {
            revert NeedsMintpass();
        }

        if (msg.value < SYMBOLIC_MINT_FEE) {
            revert MintingFeeTooLow();
        }

        delete reservations[reservationId];
        symbol[reservationId] = _symbol;
        mintAuthorizer.redeem(abi.encode(mintPassId));

        //_mint(to, reservationId, 1, "");
        _safeMint(to, reservationId);
        _setTokenURI(reservationId, _tokenURI);
        emit IPNFTMinted(to, reservationId, _tokenURI, _symbol);

        return reservationId;
    }

    /**
     * A NEW METHOD TO TEST UPGRADEABILITY
     * @param tokenId ipnft token id
     * @param newSymbol the new symbol for this ipnft
     */
    function updateSymbol(uint256 tokenId, string memory newSymbol) external {
        if (ownerOf(tokenId) != _msgSender()) {
            revert InsufficientBalance();
        }
        _updateSymbol(tokenId, newSymbol);
    }

    function _updateSymbol(uint256 tokenId, string memory newSymbol) internal {
        symbol[tokenId] = newSymbol;
        emit SymbolUpdated(tokenId, newSymbol);
    }

    /**
     * @notice grants time limited "read" access to gated resources
     * @param reader the address that should be able to access gated content
     * @param tokenId token id
     * @param until the timestamp when read access expires (unsafe but good enough for this use case)
     */
    function grantReadAccess(address reader, uint256 tokenId, uint256 until) public {
        if (ownerOf(tokenId) != _msgSender()) {
            revert InsufficientBalance();
        }

        require(until > block.timestamp, "until in the past");

        readAllowances[tokenId][reader] = until;
        emit ReadAccessGranted(tokenId, reader, until);
    }

    /**
     * @notice check whether `reader` shall be able to access gated content behind `tokenId`
     * @param reader the address in question
     * @param tokenId token id
     * @return bool current read allowance
     */
    function canRead(address reader, uint256 tokenId) public view returns (bool) {
        if (ownerOf(tokenId) == reader) {
            return true;
        }
        return readAllowances[tokenId][reader] > block.timestamp;
    }

    /// @notice in case someone sends Eth to this contract, this function gets it out again
    function withdrawAll() public payable whenNotPaused onlyOwner {
        require(payable(_msgSender()).send(address(this).balance), "transfer failed");
    }

    /// @notice upgrade authorization logic
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    {
        //empty block
    }

    /// @dev override required by Solidity.
    // function _beforeTokenTransfer(address from, address to, uint256, /* firstTokenId */ uint256 batchSize) internal override() {
    //     super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    // }
    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /// @notice https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public pure returns (string memory) {
        return "https://mint.molecule.to/contract-metadata/ipnft.json";
    }
}
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

error EmptyInput();
error InvalidInput();

/// @title minting logic
/// @notice Contains functions and events to initialize and issue an ipnft
/// @author contains code of bitbeckers, mr_bluesky
contract IPNFT3525 is
    Initializable,
    ERC3525SlotEnumerableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using ArraysUpgradeable for uint64[];
    using StringsUpgradeable for uint256;

    /// @notice Contract name
    string public constant NAME = "IP-NFT";
    /// @notice Token symbol
    string public constant SYMBOL = "IPNFT";
    /// @notice Token value decimals
    uint8 public constant DECIMALS = 0;
    /// @notice User role required in order to upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Current version of the contract
    uint16 internal _version;

    /// @notice external metadata contract
    //IIPNFTMetadata internal _metadata;

    mapping(uint256 => IPNFT) internal _ipnfts;

    struct IPNFT {
        //bytes32 nftHash;
        uint256 totalUnits;
        uint16 version;
        bool exists;
        string name;
        string description;
        string uri;
        address minter;
    }

    /*******************
     * EVENTS
     ******************/

    /// @notice Emitted when an NFT is minted
    /// @param id Id of the ipnft
    /// @param minter Address of cert minter.
    /// @param fractions Units of tokens issued under the hypercert.
    event IPNFTMinted(uint256 id, address minter, uint64[] fractions);

    /*******************
     * DEPLOY
     ******************/

    /// @notice Contract constructor logic
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Contract initialization logic
    function initialize() public initializer {
        //_metadata = IHyperCertMetadata(metadataAddress);

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC3525Upgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /*******************
     * PUBLIC
     ******************/

    /// @notice Issues a new IPNFT
    /// @param account Account issuing the new IPNFT
    /// @param data abi encoded string name_,string description_,string uri_, uint64[] fractions

    function mint(address account, bytes calldata data) public virtual {
        (IPNFT memory ipnft, uint64[] memory fractions) = _parseData(data);
        _authorizeMint(account, ipnft);
        ipnft.minter = msg.sender;

        uint256 slot = slotCount() + 1;

        _ipnfts[slot] = ipnft;

        uint256 len = fractions.length;
        for (uint256 i = 0; i < len; i++) {
            _mintValue(account, slot, fractions[i]);
        }

        emit IPNFTMinted(slot, account, fractions);
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

        if (total > balanceOf(tokenId) || total < balanceOf(tokenId))
            revert InvalidInput();

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
    /// @notice Only allowed for member of UPGRADER_ROLE
    function updateVersion() external onlyRole(UPGRADER_ROLE) {
        _version += 1;
    }

    /// @notice Returns a flag indicating if the contract supports the specified interface
    /// @param interfaceId Id of the interface
    /// @return true, if the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC3525SlotEnumerableUpgradeable, AccessControlUpgradeable)
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

    function slotURI(uint256 slotId_)
        public
        view
        override
        returns (string memory)
    {
        if (!_ipnfts[slotId_].exists) {
            revert NonExistentSlot(slotId_);
        }
        IPNFT memory slot = _ipnfts[slotId_];

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64Upgradeable.encode(
                        abi.encodePacked(
                            '{"name":"',
                            slot.name,
                            '","description":"',
                            slot.description,
                            '","external_url":"',
                            slot.uri,
                            '"}'
                        )
                    )
                )
            );
    }

    function tokenURI(uint256 tokenId_)
        public
        view
        override
        returns (string memory)
    {
        uint256 slotId = slotOf(tokenId_);

        return slotURI(slotId);
    }

    function contractURI() public pure override returns (string memory) {
        return "contract uri";
        //return _metadata.generateContractURI();
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

        _burn(tokenId_);
        ipnft.exists = false;
    }

    /*******************
     * INTERNAL
     ******************/

    /// @notice upgrade authorization logic
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(
        address /*newImplementation*/
    )
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

    function _authorizeMint(address account, IPNFT memory ipnft)
        internal
        view
        virtual
    {
        if (account == address(0)) {
            revert ToZeroAddress();
        }
    }

    /* solhint-enable code-complexity */
    /// @notice Parse bytes to ipnft and URI
    /// @param data Byte data representing the ipnft
    /// @return ipnft The parsed IPNFT struct
    function _parseData(bytes calldata data)
        internal
        pure
        virtual
        returns (IPNFT memory ipnft, uint64[] memory)
    {
        if (data.length == 0) {
            revert EmptyInput();
        }

        (
            string memory name_,
            string memory description_,
            string memory uri_,
            uint64[] memory fractions
        ) = abi.decode(data, (string, string, string, uint64[]));

        ipnft.totalUnits = fractions.getSum();
        ipnft.version = uint16(0);
        ipnft.exists = true;
        ipnft.name = name_;
        ipnft.description = description_;
        ipnft.uri = uri_;

        return (ipnft, fractions);
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC3525Upgradeable)
        returns (address sender)
    {
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

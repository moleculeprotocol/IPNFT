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
contract IPNFT3525V2 is
    Initializable,
    ERC3525SlotEnumerableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using ArraysUpgradeable for uint64[];
    using StringsUpgradeable for uint256;

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

    mapping(uint256 => IPNFT) internal _ipnfts;

    struct IPNFT {
        //bytes32 nftHash;
        uint256 totalUnits;
        uint16 version;
        bool exists;
        string name;
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
        IPNFT memory ipnft = _parseData(data);

        _authorizeMint(account, ipnft);
        ipnft.minter = msg.sender;

        uint256 slot = slotCount() + 1;

        _ipnfts[slot] = ipnft;

        _mintValue(account, slot, DEFAULT_VALUE);

        uint64[] memory defaultFractions = new uint64[](1);
        defaultFractions[0] = DEFAULT_VALUE;
        emit IPNFTMinted(slot, account, defaultFractions);
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
     * DISABLE value transfers and splits in V2
     ********************/

    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        revert("not available in V2");
    }

    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        revert("not available in V2");
    }

    function approve(
        uint256 tokenId_,
        address to_,
        uint256 value_
    ) external payable virtual override {
        revert("not available in V2");
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
        returns (IPNFT memory ipnft)
    {
        if (data.length == 0) {
            revert EmptyInput();
        }

        (string memory name_, string memory uri_) = abi.decode(
            data,
            (string, string)
        );

        ipnft.totalUnits = DEFAULT_VALUE;
        ipnft.version = uint16(0);
        ipnft.exists = true;
        ipnft.name = name_;
        ipnft.uri = uri_;

        return ipnft;
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

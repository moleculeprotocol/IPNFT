// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IPToken, Metadata as TokenMetadata } from "./IPToken.sol";
import { IPermissioner } from "./Permissioner.sol";
import { IPNFT } from "./IPNFT.sol";

error MustOwnIpnft();
error AlreadyTokenized();
error ZeroAddress();
error IPTNotControlledByTokenizer();

/// @title Tokenizer 1.3
/// @author molecule.to
/// @notice tokenizes an IPNFT to an ERC20 token (called IPToken or IPT) and controls its supply.
contract Tokenizer is UUPSUpgradeable, OwnableUpgradeable {
    event TokensCreated(
        uint256 indexed moleculesId,
        uint256 indexed ipnftId,
        address indexed tokenContract,
        address emitter,
        uint256 amount,
        string agreementCid,
        string name,
        string symbol
    );

    event IPTokenImplementationUpdated(IPToken indexed old, IPToken indexed _new);
    event PermissionerUpdated(IPermissioner indexed old, IPermissioner indexed _new);

    IPNFT internal ipnft;

    /// @dev a map of all IPTs. We're staying with the the initial term "synthesized" to keep the storage layout intact
    mapping(uint256 => IPToken) public synthesized;

    /// @dev not used, needed to ensure that storage slots are still in order after 1.1 -> 1.2, use ipTokenImplementation
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    /// @dev the permissioner checks if senders have agreed to legal requirements
    IPermissioner public permissioner;

    /// @notice the IPToken implementation this Tokenizer spawns
    IPToken public ipTokenImplementation;

    /**
     * @param _ipnft the IPNFT contract
     * @param _permissioner a permissioning contract that checks if callers have agreed to the tokenized token's legal agreements
     */
    function initialize(IPNFT _ipnft, IPermissioner _permissioner) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        ipnft = _ipnft;
        permissioner = _permissioner;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(0);
        _disableInitializers();
    }

    modifier onlyIPNFTHolder(uint256 ipnftId) {
        if (ipnft.ownerOf(ipnftId) != _msgSender()) {
            revert MustOwnIpnft();
        }
        _;
    }

    //todo: try breaking this with a faked IPToken
    modifier onlyControlledIPTs(IPToken ipToken) {
        IPToken token = synthesized[ipToken.hash()];
        if (address(token) != address(ipToken)) {
            revert IPTNotControlledByTokenizer();
        }

        TokenMetadata memory metadata = token.metadata();
        if (_msgSender() != ipnft.ownerOf(metadata.ipnftId)) {
            revert MustOwnIpnft();
        }
        _;
    }

    /**
     * @notice sets the new implementation address of the IPToken
     * @param _ipTokenImplementation address pointing to the new implementation
     */
    function setIPTokenImplementation(IPToken _ipTokenImplementation) external onlyOwner {
        /*
        could call some functions on old contract to make sure its tokenizer not another contract behind a proxy for safety
        */
        if (address(_ipTokenImplementation) == address(0)) {
            revert ZeroAddress();
        }

        emit IPTokenImplementationUpdated(ipTokenImplementation, _ipTokenImplementation);
        ipTokenImplementation = _ipTokenImplementation;
    }

    /**
     * @dev called after an upgrade to reinitialize a new permissioner impl.
     * @param _permissioner the new TermsPermissioner
     */
    function reinit(IPermissioner _permissioner) public onlyOwner reinitializer(4) {
        permissioner = _permissioner;
    }

    /**
     * @notice initializes synthesis on ipnft#id for the current asset holder.
     *         IPTokens are identified by the original token holder and the token id
     * @param ipnftId the token id on the underlying nft collection
     * @param tokenAmount the initially issued supply of IP tokens
     * @param tokenSymbol the ip token's ticker symbol
     * @param agreementCid a content hash that contains legal terms for IP token owners
     * @param signedAgreement the sender's signature over the signed agreemeent text (must be created on the client)
     * @return token a new created ERC20 token contract that represents the tokenized ipnft
     */
    function tokenizeIpnft(
        uint256 ipnftId,
        uint256 tokenAmount,
        string memory tokenSymbol,
        string memory agreementCid,
        bytes calldata signedAgreement
    ) external onlyIPNFTHolder(ipnftId) returns (IPToken token) {
        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        token = IPToken(Clones.clone(address(ipTokenImplementation)));
        string memory name = string.concat("IP Tokens of IPNFT #", Strings.toString(ipnftId));
        token.initialize(name, tokenSymbol, TokenMetadata(ipnftId, _msgSender(), agreementCid));

        uint256 tokenHash = token.hash();

        if (address(synthesized[tokenHash]) != address(0) || address(synthesized[legacyHash(ipnftId, _msgSender())]) != address(0)) {
            revert AlreadyTokenized();
        }

        synthesized[tokenHash] = token;

        //this has been called MoleculesCreated before
        emit TokensCreated(tokenHash, ipnftId, address(token), _msgSender(), tokenAmount, agreementCid, name, tokenSymbol);
        permissioner.accept(token, _msgSender(), signedAgreement);
        token.issue(_msgSender(), tokenAmount);
    }

    /**
     * @notice issues more IPTs for a given IPNFT
     * @dev you must compute the ipt hash externally.
     * @param ipToken the hash of the IPToken. See `IPToken.hash()` and `legacyHash()`. Some older IPT implementations required to compute the has as `uint256(keccak256(abi.encodePacked(owner,ipnftId)))`
     * @param amount the amount of tokens to issue
     * @param receiver the address that receives the tokens
     */
    function issue(IPToken ipToken, uint256 amount, address receiver) external onlyControlledIPTs(ipToken) {
        ipToken.issue(receiver, amount);
    }

    /**
     * @notice caps the supply of an IPT. After calling this, no new tokens can be `issue`d
     * @dev you must compute the ipt hash externally.
     * @param ipToken the IPToken to cap.
     */
    function cap(IPToken ipToken) external onlyControlledIPTs(ipToken) {
        ipToken.cap();
    }

    /**
     * @dev computes the legacy hash for an IPToken. It depended on the IPNFT owner before. Helps ensuring that the current holder cannot refractionalize an IPT
     * @param ipnftId IPNFT token id
     * @param owner the owner for the current IPT sales cycle (old concept)
     */
    function legacyHash(uint256 ipnftId, address owner) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(owner, ipnftId)));
    }

    /// @notice upgrade authorization logic
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable--line no-empty-blocks
    {
        //empty block
    }
}

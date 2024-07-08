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

    /// @notice the IPToken implementation this Tokenizer clones from
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

    //todo: try breaking this with a faked IPToken
    modifier onlyControlledIPTs(IPToken ipToken) {
        TokenMetadata memory metadata = ipToken.metadata();

        if (address(synthesized[metadata.ipnftId]) != address(ipToken)) {
            revert IPTNotControlledByTokenizer();
        }

        if (_msgSender() != ipnft.ownerOf(metadata.ipnftId)) {
            revert MustOwnIpnft();
        }
        _;
    }

    /**
     * @notice sets the new implementation address of the IPToken
     * @param _ipTokenImplementation address pointing to the new implementation
     */
    function setIPTokenImplementation(IPToken _ipTokenImplementation) public onlyOwner {
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
     * @dev sets legacy IPTs on the tokenized mapping
     */
    function reinit(IPToken _ipTokenImplementation) public onlyOwner reinitializer(5) {
        synthesized[2] = IPToken(0x6034e0d6999741f07cb6Fb1162cBAA46a1D33d36);
        synthesized[28] = IPToken(0x7b66E84Be78772a3afAF5ba8c1993a1B5D05F9C2);
        synthesized[37] = IPToken(0xBcE56276591128047313e64744b3EBE03998783f);

        setIPTokenImplementation(_ipTokenImplementation);
    }

    /**
     * @notice tokenizes ipnft#id for the current asset holder.
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
    ) external returns (IPToken token) {
        if (ipnft.ownerOf(ipnftId) != _msgSender()) {
            revert MustOwnIpnft();
        }
        if (address(synthesized[ipnftId]) != address(0)) {
            revert AlreadyTokenized();
        }

        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        token = IPToken(Clones.clone(address(ipTokenImplementation)));
        string memory name = string.concat("IP Tokens of IPNFT #", Strings.toString(ipnftId));
        token.initialize(ipnftId, name, tokenSymbol, _msgSender(), agreementCid);

        synthesized[ipnftId] = token;

        //this has been called MoleculesCreated before
        emit TokensCreated(
            //upwards compatibility: signaling an unique "Molecules ID" as first parameter ("sales cycle id"). This is unused and not interpreted.
            uint256(keccak256(abi.encodePacked(ipnftId))),
            ipnftId,
            address(token),
            _msgSender(),
            tokenAmount,
            agreementCid,
            name,
            tokenSymbol
        );
        permissioner.accept(token, _msgSender(), signedAgreement);
        token.issue(_msgSender(), tokenAmount);
    }

    /**
     * @notice issues more IPTs when not capped. This can be used for new owners of legacy IPTs that otherwise wouldn't be able to pass their `onlyIssuerOrOwner` gate
     * @param ipToken The ip token to control
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

    /// @dev this will be called by IPTs to avoid handing over yet another IPNFT address (they already know this Tokenizer contract as their owner)
    function ownerOf(uint256 ipnftId) external view returns (address) {
        return ipnft.ownerOf(ipnftId);
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

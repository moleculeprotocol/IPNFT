// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IIPToken, Metadata as TokenMetadata } from "./IIPToken.sol";
import { IPToken } from "./IPToken.sol";
import { WrappedIPToken } from "./WrappedIPToken.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IControlIPTs } from "./IControlIPTs.sol";
import { IPNFT } from "./IPNFT.sol";
import { IPermissioner } from "./Permissioner.sol";

error MustControlIpnft();
error AlreadyTokenized();
error ZeroAddress();
error IPTNotControlledByTokenizer();
error InvalidTokenContract();
error InvalidTokenDecimals();

/// @title Tokenizer 1.4
/// @author molecule.xyz
/// @notice tokenizes an IPNFT to an ERC20 token (called IPToken or IPT) and controls its supply.
contract Tokenizer is UUPSUpgradeable, OwnableUpgradeable, IControlIPTs {
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

    // @dev @TODO: index these topics
    event TokenWrapped(IERC20Metadata tokenContract, IIPToken wrappedIpt);
    event IPTokenImplementationUpdated(IIPToken indexed old, IIPToken indexed _new);
    event WrappedIPTokenImplementationUpdated(WrappedIPToken indexed old, WrappedIPToken indexed _new);
    event PermissionerUpdated(IPermissioner indexed old, IPermissioner indexed _new);

    IPNFT internal ipnft;

    /// @dev a map of all IPTs. We're staying with the the initial term "synthesized" to keep the storage layout intact
    mapping(uint256 => IIPToken) public synthesized;

    /// @dev not used, needed to ensure that storage slots are still in order after 1.1 -> 1.2, use ipTokenImplementation
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    /// @dev the permissioner checks if senders have agreed to legal requirements
    IPermissioner public permissioner;

    /// @notice the IPToken implementation this Tokenizer clones from
    IPToken public ipTokenImplementation;

    /// @notice a WrappedIPToken implementation, used for attaching existing ERC-20 contracts as metadata bearing IPTs
    WrappedIPToken public wrappedTokenImplementation;

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

    function getIPNFTContract() public view returns (IPNFT) {
        return ipnft;
    }

    modifier onlyController(IPToken ipToken) {
        TokenMetadata memory metadata = ipToken.metadata();

        if (address(synthesized[metadata.ipnftId]) != address(ipToken)) {
            revert IPTNotControlledByTokenizer();
        }

        if (_msgSender() != controllerOf(metadata.ipnftId)) {
            revert MustControlIpnft();
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
     * @notice sets the new implementation address of the WrappedIPToken
     * @param _wrappedIpTokenImplementation address pointing to the new implementation
     */
    function setWrappedIPTokenImplementation(WrappedIPToken _wrappedIpTokenImplementation) public onlyOwner {
        /*
        could call some functions on old contract to make sure its tokenizer not another contract behind a proxy for safety
        */
        if (address(_wrappedIpTokenImplementation) == address(0)) {
            revert ZeroAddress();
        }

        emit WrappedIPTokenImplementationUpdated(wrappedTokenImplementation, _wrappedIpTokenImplementation);
        wrappedTokenImplementation = _wrappedIpTokenImplementation;
    }

    /**
     * @dev sets legacy IPTs on the tokenized mapping
     */
    function reinit(WrappedIPToken _wrappedIpTokenImplementation, IPToken _ipTokenImplementation) public onlyOwner reinitializer(6) {
        setIPTokenImplementation(_ipTokenImplementation);
        setWrappedIPTokenImplementation(_wrappedIpTokenImplementation);
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
        if (_msgSender() != controllerOf(ipnftId)) {
            revert MustControlIpnft();
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
            //upwards compatibility: signaling a unique "Molecules ID" as first parameter ("sales cycle id"). This is unused and not interpreted.
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
     * @notice since 1.4 allows attaching an existing ERC20 contract as IPT
     * @param ipnftId the token id on the underlying nft collection
     * @param agreementCid a content hash that contains legal terms for IP token owners
     * @param signedAgreement the sender's signature over the signed agreemeent text (must be created on the client)
     * @param tokenContract the ERC20 token contract to wrap
     * @return IPToken a wrapped IPToken that represents the tokenized ipnft for permissioners and carries metadata
     */
    function attachIpt(uint256 ipnftId, string memory agreementCid, bytes calldata signedAgreement, IERC20Metadata tokenContract)
        external
        returns (IIPToken)
    {
        if (_msgSender() != controllerOf(ipnftId)) {
            revert MustControlIpnft();
        }
        if (address(synthesized[ipnftId]) != address(0)) {
            revert AlreadyTokenized();
        }

        // Sanity checks for token properties
        _validateTokenContract(tokenContract);

        WrappedIPToken wrappedIpt = WrappedIPToken(Clones.clone(address(wrappedTokenImplementation)));
        wrappedIpt.initialize(ipnftId, _msgSender(), agreementCid, tokenContract);
        synthesized[ipnftId] = wrappedIpt;

        emit TokensCreated(
            uint256(keccak256(abi.encodePacked(ipnftId))),
            ipnftId,
            address(tokenContract),
            _msgSender(),
            tokenContract.totalSupply(),
            agreementCid,
            tokenContract.name(),
            tokenContract.symbol()
        );
        emit TokenWrapped(tokenContract, wrappedIpt);
        permissioner.accept(wrappedIpt, _msgSender(), signedAgreement);
        return wrappedIpt;
    }

    /**
     * @notice issues more IPTs when not capped. This can be used for new owners of legacy IPTs that otherwise wouldn't be able to pass their `onlyIssuerOrOwner` gate
     * @param ipToken The ip token to control
     * @param amount the amount of tokens to issue
     * @param receiver the address that receives the tokens
     */
    function issue(IPToken ipToken, uint256 amount, address receiver) external onlyController(ipToken) {
        ipToken.issue(receiver, amount);
    }

    /**
     * @notice caps the supply of an IPT. After calling this, no new tokens can be `issue`d
     * @dev you must compute the ipt hash externally.
     * @param ipToken the IPToken to cap.
     */
    function cap(IPToken ipToken) external onlyController(ipToken) {
        ipToken.cap();
    }

    /// @dev this will be called by IPTs. Right now the controller is the IPNFT's current owner, it can be a Governor in the future.
    function controllerOf(uint256 ipnftId) public view override returns (address) {
        return ipnft.ownerOf(ipnftId);
    }

    /**
     * @notice Validates token contract properties before wrapping
     * @param tokenContract The ERC20 token contract to validate
     */
    function _validateTokenContract(IERC20Metadata tokenContract) internal view {
        // Check if contract address is valid
        if (address(tokenContract) == address(0)) {
            revert ZeroAddress();
        }

        // Check if it's a contract (has code)
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(tokenContract)
        }
        if (codeSize == 0) {
            revert InvalidTokenContract();
        }

        // Validate decimals - should be reasonable (0-18)
        try tokenContract.decimals() returns (uint8 decimals) {
            if (decimals > 18) {
                revert InvalidTokenDecimals();
            }
        } catch {
            revert InvalidTokenDecimals();
        }
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

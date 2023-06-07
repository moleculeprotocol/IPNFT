// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Molecules, Metadata as MoleculesMetadata } from "./Molecules.sol";
import { IPNFT } from "./IPNFT.sol";

error MustOwnIpnft();
error AlreadySynthesized();

/// @title Synthesizer
/// @author molecule.to
/// @notice synthesizes an IPNFT to an ERC20 token (called molecules) and controls its supply.
///         Allows molecule holders to withdraw sales shares when the IPNFT is sold
contract Synthesizer is UUPSUpgradeable, OwnableUpgradeable {
    event MoleculesCreated(
        uint256 indexed moleculesId,
        uint256 indexed ipnftId,
        address indexed tokenContract,
        address emitter,
        uint256 amount,
        string agreementCid,
        string name,
        string symbol
    );

    IPNFT internal ipnft;

    mapping(uint256 => Molecules) public synthesized;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        ipnft = _ipnft;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new Molecules());
        _disableInitializers();
    }

    /**
     * @notice initializes synthesis on ipnft#id for the current asset holder.
     *         molecules are identified by the original token holder and the token id
     * @param ipnftId the token id on the underlying nft collection
     * @param moleculesAmount the initially issued supply of Molecules
     * @param agreementCid a content hash that contains legal terms for Molecule owners
     * @return molecules a new created ERC20 token contract that represents the molecules
     */
    function synthesizeIpnft(uint256 ipnftId, uint256 moleculesAmount, string calldata agreementCid) external returns (Molecules molecules) {
        if (ipnft.ownerOf(ipnftId) != _msgSender()) {
            revert MustOwnIpnft();
        }
        string memory tokenSymbol = string.concat(ipnft.symbol(ipnftId), "-MOL");
        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        molecules = Molecules(Clones.clone(tokenImplementation));
        string memory name = string.concat("Molecules of IPNFT #", Strings.toString(ipnftId));
        molecules.initialize(name, tokenSymbol, MoleculesMetadata(ipnftId, _msgSender(), agreementCid));

        uint256 moleculeHash = molecules.hash();
        // ensure we can only call this once per sales cycle
        if (address(synthesized[moleculeHash]) != address(0)) {
            revert AlreadySynthesized();
        }

        synthesized[moleculeHash] = molecules;

        emit MoleculesCreated(moleculeHash, ipnftId, address(molecules), _msgSender(), moleculesAmount, agreementCid, name, tokenSymbol);

        //if we want to take a protocol fee, this might be a good point of doing so.
        molecules.issue(_msgSender(), moleculesAmount);
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

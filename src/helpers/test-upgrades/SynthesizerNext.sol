// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MustOwnIpnft, AlreadySynthesized } from "../../Synthesizer.sol";
import { Molecules, Metadata, TokenCapped } from "../../Molecules.sol";
import { IPNFT } from "../../IPNFT.sol";

/// @title MoleculesNext
/// @author molecule.to
/// @notice this is a template contract that's spawned by the synthesizer
/// @notice the owner of this contract is always the synthesizer contract
contract MoleculesNext is Molecules {
    uint256 public aNewStateVar;

    function setAStateVar(uint256 newVal) public {
        aNewStateVar = newVal;
    }
}

/// @title SynthesizerNext
/// @author molecule.to
/// @notice this is used to test upgrade safety
contract SynthesizerNext is UUPSUpgradeable, OwnableUpgradeable {
    event MoleculesCreated(
        uint256 indexed ipnftId, address indexed tokenContract, address emitter, uint256 amount, string agreementCid, string name, string symbol
    );

    IPNFT ipnft;

    mapping(uint256 => MoleculesNext) public synthesized;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        ipnft = _ipnft;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new MoleculesNext());
        _disableInitializers();
    }

    function synthesizeIpnft(uint256 ipnftId, uint256 moleculesAmount, string calldata agreementCid) external returns (MoleculesNext token) {
        if (ipnft.ownerOf(ipnftId) != _msgSender()) {
            revert MustOwnIpnft();
        }
        string memory ipnftSymbol = ipnft.symbol(ipnftId);

        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        MoleculesNext molecules = MoleculesNext(Clones.clone(tokenImplementation));
        string memory name = string.concat("Molecules of IPNFT #", Strings.toString(ipnftId));
        molecules.initialize(name, string.concat(ipnftSymbol, "-MOL"), Metadata(ipnftId, _msgSender(), agreementCid));
        uint256 moleculeHash = molecules.hash();
        // ensure we can only call this once per sales cycle
        if (address(synthesized[moleculeHash]) != address(0)) {
            revert AlreadySynthesized();
        }

        synthesized[moleculeHash] = molecules;

        emit MoleculesCreated(ipnftId, address(molecules), _msgSender(), moleculesAmount, agreementCid, name, ipnftSymbol);

        //if we want to take a protocol fee, this might be a good point of doing so.
        molecules.issue(_msgSender(), moleculesAmount);

        return molecules;
    }

    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    { }
}

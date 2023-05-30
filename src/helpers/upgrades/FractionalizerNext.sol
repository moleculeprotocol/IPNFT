// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MustOwnIpnft, NoSymbol, AlreadyFractionalized } from "../../Fractionalizer.sol";
import { FractionalizedToken, Metadata, TokenCapped } from "../../FractionalizedToken.sol";
import { IPNFT } from "../../IPNFT.sol";

/// @title FractionalizedTokenNext
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer
/// @notice the owner of this contract is always the fractionalizer contract
contract FractionalizedTokenNext is FractionalizedToken {
    uint256 public aNewStateVar;

    function setAStateVar(uint256 newVal) public {
        aNewStateVar = newVal;
    }
}

/// @title FractionalizerNext
/// @author molecule.to
/// @notice this is used to test upgrade safety
contract FractionalizerNext is UUPSUpgradeable, OwnableUpgradeable {
    event FractionsCreated(
        uint256 indexed ipnftId, address indexed tokenContract, address emitter, uint256 amount, string agreementCid, string name, string symbol
    );

    IPNFT ipnft;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => FractionalizedTokenNext) public fractionalized;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        ipnft = _ipnft;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new FractionalizedTokenNext());
        _disableInitializers();
    }

    function fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid)
        external
        returns (FractionalizedTokenNext token)
    {
        if (ipnft.balanceOf(_msgSender(), ipnftId) != 1) {
            revert MustOwnIpnft();
        }
        string memory ipnftSymbol = ipnft.symbol(ipnftId);
        if (bytes(ipnftSymbol).length == 0) {
            revert NoSymbol();
        }

        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        FractionalizedTokenNext fractionalizedToken = FractionalizedTokenNext(Clones.clone(tokenImplementation));
        string memory name = string.concat("Fractions of IPNFT #", Strings.toString(ipnftId));
        fractionalizedToken.initialize(name, string.concat(ipnftSymbol, "-MOL"), Metadata(ipnftId, _msgSender(), agreementCid));
        uint256 fractionHash = fractionalizedToken.hash();
        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionHash]) != address(0)) {
            revert AlreadyFractionalized();
        }

        fractionalized[fractionHash] = fractionalizedToken;

        emit FractionsCreated(ipnftId, address(fractionalizedToken), _msgSender(), fractionsAmount, agreementCid, name, ipnftSymbol);

        //if we want to take a protocol fee, this might be a good point of doing so.
        fractionalizedToken.issue(_msgSender(), fractionsAmount);

        return fractionalizedToken;
    }

    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    { }
}

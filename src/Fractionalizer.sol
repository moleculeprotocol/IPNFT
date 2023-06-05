// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { FractionalizedToken, Metadata as FractionalizedTokenMetadata } from "./FractionalizedToken.sol";
import { IPNFT } from "./IPNFT.sol";

error MustOwnIpnft();
error AlreadyFractionalized();

/// @title Fractionalizer
/// @author molecule.to
/// @notice fractionalizes an IPNFT to an ERC20 token and controls its supply.
///         Allows fraction holders to withdraw sales shares when the IPNFT is sold
contract Fractionalizer is UUPSUpgradeable, OwnableUpgradeable {
    event FractionsCreated(
        uint256 indexed fractionId,
        uint256 indexed ipnftId,
        address indexed tokenContract,
        address emitter,
        uint256 amount,
        string agreementCid,
        string name,
        string symbol
    );

    IPNFT internal ipnft;

    address internal feeReceiver;
    uint256 internal fractionalizationPercentage;

    mapping(uint256 => FractionalizedToken) public fractionalized;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        ipnft = _ipnft;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new FractionalizedToken());
        _disableInitializers();
    }

    /**
     * @notice we're not taking any fees. If we once decided to do so, this can be used to update the fee receiver
     * @param _feeReceiver the address that will receive fraction fees
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }

    /**
     * @notice unused in this version
     * @param fractionalizationPercentage_  uint256 the fee percentage `feeReceiver` takes on a new fractionalization
     */
    function setReceiverPercentage(uint256 fractionalizationPercentage_) external onlyOwner {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    /**
     * @notice initializes fractions on ipnft#id for the current asset holder.
     *         Fractional tokens are identified by the original token holder and the token id
     * @param ipnftId the token id on the underlying nft collection
     * @param fractionsAmount the initially issued supply of fraction tokens
     * @param agreementCid a content hash that contains legal terms for fraction owners
     * @return fractionalizedToken a new created ERC20 token contract that represents the fractions
     */
    function fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid)
        external
        returns (FractionalizedToken fractionalizedToken)
    {
        if (ipnft.ownerOf(ipnftId) != _msgSender()) {
            revert MustOwnIpnft();
        }
        string memory tokenSymbol = string.concat(ipnft.symbol(ipnftId), "-MOL");
        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        fractionalizedToken = FractionalizedToken(Clones.clone(tokenImplementation));
        string memory name = string.concat("Fractions of IPNFT #", Strings.toString(ipnftId));
        fractionalizedToken.initialize(name, tokenSymbol, FractionalizedTokenMetadata(ipnftId, _msgSender(), agreementCid));

        uint256 fractionHash = fractionalizedToken.hash();
        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionHash]) != address(0)) {
            revert AlreadyFractionalized();
        }

        fractionalized[fractionHash] = fractionalizedToken;

        emit FractionsCreated(fractionHash, ipnftId, address(fractionalizedToken), _msgSender(), fractionsAmount, agreementCid, name, tokenSymbol);

        //if we want to take a protocol fee, this might be a good point of doing so.
        fractionalizedToken.issue(_msgSender(), fractionsAmount);
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

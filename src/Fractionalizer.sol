// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { FractionalizedToken, Metadata as FractionalizedTokenMetadata } from "./FractionalizedToken.sol";
import { IPNFT } from "./IPNFT.sol";

enum FractionalizationPhase {
    FRACTIONALIZED,
    CLAIMING
}

struct Fractionalized {
    FractionalizedToken tokenContract;
    FractionalizationPhase phase;
}

error ToZeroAddress();
error InsufficientBalance();
error TermsNotAccepted();

error BadSupply();
error MustOwnIpnft();
error NoSymbol();
error AlreadyFractionalized();

error AlreadyClaiming();
error NotClaimingYet();

/// @title Fractionalizer
/// @author molecule.to
/// @notice fractionalizes an IPNFT to an ERC20 token and controls its supply.
///         Allows fraction holders to withdraw sales shares when the IPNFT is sold
contract Fractionalizer is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
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
    event PhaseTransitioned(uint256 fractionId, FractionalizationPhase);

    IPNFT ipnft;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractionalized) public fractionalized;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    bytes32 public constant STATE_MANAGER_ROLE = keccak256("STATE_MANAGER_ROLE");

    function initialize(IPNFT _ipnft) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __ReentrancyGuard_init();

        ipnft = _ipnft;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new FractionalizedToken());
        _disableInitializers();
    }

    /**
     * @notice we're not taking any fees. If we once decided to do so, this can be used to update the fee receiver
     */
    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        if (_feeReceiver == address(0)) {
            revert ToZeroAddress();
        }
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) external onlyOwner {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    //todo: only SalesShareDistributor and his frens can call this
    function startClamingPhase(uint256 fractionId) public onlyRole(STATE_MANAGER_ROLE) {
        fractionalized[fractionId].phase = FractionalizationPhase.CLAIMING;
        emit PhaseTransitioned(fractionId, FractionalizationPhase.CLAIMING);
    }

    /**
     * @notice
     * @param ipnftId          uint256  the token id on the origin collection
     * @param fractionsAmount  uint256  the initial amount of fractions issued
     * @param agreementCid     bytes32  a content hash that identifies the terms underlying the issued fractions
     */
    function fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid) external returns (uint256 fractionId) {
        if (ipnft.totalSupply(ipnftId) != 1) {
            revert BadSupply();
        }
        if (ipnft.balanceOf(_msgSender(), ipnftId) != 1) {
            revert MustOwnIpnft();
        }
        string memory ipnftSymbol = ipnft.symbol(ipnftId);
        if (bytes(ipnftSymbol).length == 0) {
            revert NoSymbol();
        }

        fractionId = uint256(keccak256(abi.encodePacked(_msgSender(), ipnftId)));

        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionId].tokenContract) != address(0)) {
            revert AlreadyFractionalized();
        }

        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        FractionalizedToken fractionalizedToken = FractionalizedToken(Clones.clone(tokenImplementation));
        string memory name = string(abi.encodePacked("Fractions of IPNFT #", Strings.toString(ipnftId)));

        fractionalized[fractionId] = Fractionalized(fractionalizedToken, FractionalizationPhase.FRACTIONALIZED);
        emit FractionsCreated(fractionId, ipnftId, address(fractionalizedToken), _msgSender(), fractionsAmount, agreementCid, name, ipnftSymbol);

        fractionalizedToken.initialize(name, ipnftSymbol, FractionalizedTokenMetadata(ipnftId, _msgSender(), agreementCid));

        //todo: if we want to take a protocol fee, this might be a good point of doing so.
        fractionalizedToken.issue(_msgSender(), fractionsAmount);
    }

    /**
     * @notice we deliberately allow the fraction initializer to increase the fraction supply at will
     *         as long as the underlying asset has not been sold yet
     *
     * @param fractionId uint256
     * @param fractionsAmount uint256
     */
    function increaseFractions(uint256 fractionId, uint256 fractionsAmount) external {
        Fractionalized memory _fractionalized = fractionalized[fractionId];
        if (_fractionalized.phase == FractionalizationPhase.CLAIMING) {
            revert AlreadyClaiming();
        }
        (, address originalOwner,) = _fractionalized.tokenContract.metadata();
        if (_msgSender() != originalOwner) {
            revert MustOwnIpnft();
        }

        _fractionalized.tokenContract.issue(_msgSender(), fractionsAmount);
    }

    /// @notice upgrade authorization logic
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    {
        //empty block
    }

    /**
     * @notice contract metadata, compatible to ERC1155
     * @param fractionId uint256
     */
    function uri(uint256 fractionId) public view returns (string memory) {
        Fractionalized memory frac = fractionalized[fractionId];
        FractionalizedToken tokenContract = frac.tokenContract;
        (uint256 ipnftId, address originalOwner, string memory agreementCid) = tokenContract.metadata();
        string memory tokenId = Strings.toString(ipnftId);

        string memory props = string(
            abi.encodePacked(
                '"properties": {',
                '"ipnft_id": ',
                tokenId,
                ',"agreement_content": "ipfs://',
                agreementCid,
                '","original_owner": "',
                Strings.toHexString(originalOwner),
                '","erc20_contract": "',
                Strings.toHexString(address(tokenContract)),
                '","supply": "',
                Strings.toString(tokenContract.totalIssued()),
                '"}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "Fractions of IPNFT #',
                        tokenId,
                        '","description": "this token represents fractions of the underlying asset","decimals": 18,"external_url": "https://molecule.to","image": "",',
                        props,
                        "}"
                    )
                )
            )
        );
    }
}

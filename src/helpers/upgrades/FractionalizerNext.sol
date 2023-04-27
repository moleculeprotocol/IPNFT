// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { SchmackoSwap, ListingState } from "../../SchmackoSwap.sol";
import { IPNFT } from "../../IPNFT.sol";

struct Fractionalized {
    uint256 tokenId;
    //needed to remember an individual's share after others burn their tokens
    uint256 totalIssued;
    address originalOwner;
    string agreementCid;
    FractionalizedTokenUpgradeableNext tokenContract; //the erc20 token contract representing the fractions
    uint256 fulfilledListingId;
    IERC20 paymentToken;
    uint256 paidPrice;
}

error BadSupply();
error MustOwnIpnft();
error NoSymbol();
error AlreadyFractionalized();

/// @title FractionalizedToken
/// @author molecule.to
/// @notice this is a template contract that's spawned by the fractionalizer
/// @notice the owner of this contract is always the fractionalizer contract
contract FractionalizedTokenUpgradeableNext is IERC20Upgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    uint256 public aNewStateVar;

    function initialize(string memory name, string memory symbol) public initializer {
        __Ownable_init();
        __ERC20_init(name, symbol);
    }

    function issue(address receiver, uint256 amount) public onlyOwner {
        _mint(receiver, amount);
    }

    function setAStateVar(uint256 newVal) public {
        aNewStateVar = newVal;
    }
}

/// @title Fractionalizer
/// @author molecule.to
/// @notice this is used to test upgrade safety
contract FractionalizerNext is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

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

    IPNFT ipnft;
    SchmackoSwap schmackoSwap;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractionalized) public fractionalized;
    mapping(address => mapping(uint256 => uint256)) claimAllowance;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft, SchmackoSwap _schmackoSwap) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __ReentrancyGuard_init();

        ipnft = _ipnft;
        schmackoSwap = _schmackoSwap;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new FractionalizedTokenUpgradeableNext());
        _disableInitializers();
    }

    function balanceOf(address owner, uint256 fractionId) public view returns (uint256) {
        return fractionalized[fractionId].tokenContract.balanceOf(owner);
    }

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

        if (address(fractionalized[fractionId].originalOwner) != address(0)) {
            revert AlreadyFractionalized();
        }

        FractionalizedTokenUpgradeableNext fractionalizedToken = FractionalizedTokenUpgradeableNext(Clones.clone(tokenImplementation));
        string memory name = string(abi.encodePacked("Fractions of IPNFT #", Strings.toString(ipnftId)));
        fractionalized[fractionId] =
            Fractionalized(ipnftId, fractionsAmount, _msgSender(), agreementCid, fractionalizedToken, 0, IERC20(address(0)), 0);
        emit FractionsCreated(fractionId, ipnftId, address(fractionalizedToken), _msgSender(), fractionsAmount, agreementCid, name, ipnftSymbol);

        fractionalizedToken.initialize(name, ipnftSymbol);
        fractionalizedToken.issue(_msgSender(), fractionsAmount);
    }

    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    { }
}

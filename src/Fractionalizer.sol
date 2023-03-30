// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155ReceiverUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { ERC2771ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ListingState } from "./SchmackoSwap.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC1155Supply } from "./IERC1155Supply.sol";

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

struct Fractionalized {
    address collection;
    uint256 tokenId;
    //needed to remember an individual's share after others burn their tokens
    uint256 totalIssued;
    address originalOwner;
    bytes32 agreementHash;
    IERC20 paymentToken;
    uint256 paidPrice;
}

/// @title Fractionalizer
/// @author molecule.to
/// @notice only deployed on L2, controlled by xdomain messages
contract Fractionalizer is ERC1155SupplyUpgradeable, UUPSUpgradeable, ERC2771ContextUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    event FractionsCreated(address indexed collection, uint256 indexed tokenId, address emitter, uint256 indexed fractionId, bytes32 agreementHash);
    event SalesActivated(uint256 fractionId, address paymentToken, uint256 paidPrice);
    event TermsAccepted(uint256 indexed fractionId, address indexed signer);
    event SharesClaimed(uint256 indexed fractionId, address indexed claimer, uint256 amount);
    //listen for mints instead:
    //event FractionsEmitted(uint256 fractionId, uint256 amount);

    address feeReceiver;
    uint256 fractionalizationPercentage;
    ICrossDomainMessenger crossDomainMessenger;

    mapping(uint256 => Fractionalized) public fractionalized;
    mapping(uint256 => mapping(address => bool)) public signedTerms;

    address fractionalizerDispatcherOnL1;

    modifier onlyXDomain() {
        if (_msgSender() != address(crossDomainMessenger)) {
            revert("this must only be called by the l1l2 bridge");
        }
        _;
    }

    modifier onlyDispatcher() {
        if (fractionalizerDispatcherOnL1 != crossDomainMessenger.xDomainMessageSender()) {
            revert("may only be called by the dispatcher contract on L1");
        }
        _;
    }

    modifier notClaiming(uint256 fractionId) {
        if (address(fractionalized[fractionId].paymentToken) != address(0)) {
            revert("already in claiming phase");
        }
        _;
    }

    //todo consider setting this one: https://docs.opengsn.org/contracts/#trusted-forwarder-minimum-viable-trust
    //görli op: 0xB2b5841DBeF766d4b521221732F9B618fCf34A87
    //op: 0xB2b5841DBeF766d4b521221732F9B618fCf34A87
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        _disableInitializers();
        //see https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/pull/155
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        crossDomainMessenger = ICrossDomainMessenger(0x4200000000000000000000000000000000000007);
        //not calling the ERC1155 initializer, since we don't need an URI
    }

    function setFractionalizerDispatcherL1(address _fractionalizerDispatcherOnL1) public onlyOwner {
        fractionalizerDispatcherOnL1 = _fractionalizerDispatcherOnL1;
    }

    function setFeeReceiver(address _feeReceiver) public {
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) external {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address sender) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }

    /**
     * @param fractionId the fractionalized token id as computed on the l1 network
     */
    function fractionalizeUniqueERC1155(
        uint256 fractionId,
        address collection,
        uint256 tokenId,
        address originalOwner,
        address recipient,
        bytes32 agreementHash,
        uint256 fractionsAmount
    ) public onlyXDomain onlyDispatcher {
        if (uint256(keccak256(abi.encodePacked(originalOwner, collection, tokenId))) != fractionId) {
            revert("only the owner may fractionalize on the collection");
        }

        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionId].collection) != address(0)) {
            revert("token is already fractionalized");
        }

        fractionalized[fractionId] = Fractionalized(collection, tokenId, fractionsAmount, originalOwner, agreementHash, IERC20(address(0)), 0);

        _mint(recipient, fractionId, fractionsAmount, "");
        //todo: if we want to take a protocol fee, this might be agood point of doing so.
        emit FractionsCreated(collection, tokenId, originalOwner, fractionId, agreementHash);
    }

    function increaseFractions(uint256 fractionId, uint256 fractionsAmount) external notClaiming(fractionId) {
        Fractionalized memory _fractionalized = fractionalized[fractionId];

        if (_msgSender() != _fractionalized.originalOwner) {
            revert("only the original owner can update the distribution scheme");
        }

        fractionalized[fractionId].totalIssued += fractionsAmount;
        _mint(_fractionalized.originalOwner, fractionId, fractionsAmount, "");
    }

    /**
     * @dev since we gate this with `onlyDispatcher`, we can assume that L1 has checked that the trade has actually occurred.
     */
    function afterSale(uint256 fractionId, address paymentToken, uint256 paidPrice) public onlyXDomain onlyDispatcher {
        Fractionalized storage frac = fractionalized[fractionId];

        //TODO: this is a warning, we still could proceed, since it's too late here anyway ;)
        // if (paymentToken.balanceOf(address(this)) < askPrice) {
        //     revert("the fulfillment doesn't match the ask");
        // }
        frac.paymentToken = IERC20(paymentToken);
        frac.paidPrice = paidPrice;
        emit SalesActivated(fractionId, paymentToken, paidPrice);
    }

    function claimableTokens(uint256 fractionId, address tokenHolder) public view returns (IERC20 paymentToken, uint256 amount) {
        Fractionalized memory frac = fractionalized[fractionId];

        if (address(frac.paymentToken) == address(0) || frac.paidPrice == 0) {
            revert("claiming not available (yet)");
        }

        uint256 balance = balanceOf(tokenHolder, fractionId);
        //todo: check this 10 times:
        return (frac.paymentToken, (balance * frac.paidPrice) / frac.totalIssued);
    }

    function burnToWithdrawShare(uint256 fractionId, bytes memory signature) public {
        acceptTerms(fractionId, signature);
        burnToWithdrawShare(fractionId);
    }

    function burnToWithdrawShare(uint256 fractionId) public {
        uint256 balance = balanceOf(_msgSender(), fractionId);
        if (balance == 0) {
            revert("you dont own any fractions");
        }
        if (!signedTerms[fractionId][_msgSender()]) {
            revert("you haven't accepted the terms");
        }

        (IERC20 paymentToken, uint256 erc20shares) = claimableTokens(fractionId, _msgSender());
        if (erc20shares == 0) {
            revert("shares are 0");
        }

        _burn(_msgSender(), fractionId, balance);
        paymentToken.safeTransfer(_msgSender(), erc20shares);
    }

    function specificTermsV1(uint256 fractionId) public view returns (string memory) {
        Fractionalized memory frac = fractionalized[fractionId];

        return string(
            abi.encodePacked(
                "As a fraction holder of IPNFT #",
                Strings.toString(frac.tokenId),
                ", I accept all terms that I've read here: ",
                Strings.toHexString(uint256(frac.agreementHash)),
                "\n\n",
                "Chain Id: ",
                Strings.toString(block.chainid),
                "\n",
                "Version: 1"
            )
        );
    }

    function isValidSignature(uint256 fractionId, address signer, bytes memory signature) public view returns (bool) {
        bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(specificTermsV1(fractionId)));
        return SignatureChecker.isValidSignatureNow(signer, termsHash, signature);
    }

    /**
     * @param fractionId fraction id
     * @param signature bytes encoded signature, for eip155: abi.encodePacked(r, s, v)
     */
    function acceptTerms(uint256 fractionId, bytes memory signature) public {
        if (!isValidSignature(fractionId, _msgSender(), signature)) {
            revert("signature not valid");
        }
        signedTerms[fractionId][_msgSender()] = true;
        emit TermsAccepted(fractionId, _msgSender());
    }
    // function supportsInterface(bytes4 interfaceId) public view virtual override (ERC1155ReceiverUpgradeable, ERC1155Upgradeable) returns (bool) {
    //     return super.supportsInterface(interfaceId);
    // }

    /// @notice upgrade authorization logic
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    {
        //empty block
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        Fractionalized memory frac = fractionalized[id];

        string memory collection = Strings.toHexString(frac.collection);
        string memory tokenId = Strings.toString(frac.tokenId);

        string memory props = string(
            abi.encodePacked(
                '"properties": {',
                '"collection": "',
                collection,
                '","token_id": ',
                tokenId,
                ',"agreement_hash": "',
                Strings.toHexString(uint256(frac.agreementHash)),
                '","original_owner": "',
                Strings.toHexString(frac.originalOwner),
                '","supply": ',
                Strings.toString(frac.totalIssued),
                "}"
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "Fractions of ',
                        collection,
                        " / ",
                        tokenId,
                        '","description": "this token represents fractions of the underlying asset","decimals": 0,"external_url": "https://molecule.to","image": "",',
                        props,
                        "}"
                    )
                )
            )
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155ReceiverUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ListingState } from "./SchmackoSwap.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1155Supply } from "./IERC1155Supply.sol";

import { IPNFT } from "./IPNFT.sol";
import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";

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
/// @notice
contract Fractionalizer is ERC1155SupplyUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    struct Fractionalized {
        IERC1155Supply collection;
        uint256 tokenId;
        //needed to remember an individual's share after others burn their tokens
        uint256 totalIssued;
        address originalOwner;
        bytes32 agreementHash;
        uint256 fulfilledListingId;
    }

    event FractionsCreated(address indexed collection, uint256 indexed tokenId, address emitter, uint256 indexed fractionId, bytes32 agreementHash);
    event SalesActivated(uint256 fractionId, address paymentToken, uint256 paidPrice);
    event TermsAccepted(uint256 indexed fractionId, address indexed signer);
    event SharesClaimed(uint256 indexed fractionId, address indexed claimer, uint256 amount);
    //listen for mints instead:
    //event FractionsEmitted(uint256 fractionId, uint256 amount);

    IPNFT ipnft;
    SchmackoSwap schmackoSwap;

    address feeReceiver;
    uint256 fractionalizationPercentage;
    mapping(uint256 => Fractionalized) public fractionalized;
    mapping(address => mapping(uint256 => uint256)) claimAllowance;

    function initialize(SchmackoSwap _schmackoSwap) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        schmackoSwap = _schmackoSwap;
        //not calling the ERC1155 initializer, since we don't need an URI
    }

    modifier notClaiming(uint256 fractionId) {
        if (address(fractionalized[fractionId].paymentToken) != address(0)) {
            revert("already in claiming phase");
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function setFeeReceiver(address _feeReceiver) public {
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) external {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    function fractionalizeUniqueERC1155(IERC1155Supply collection, uint256 tokenId, bytes32 agreementHash, uint256 fractionsAmount)
        external
        returns (uint256 fractionId)
    {
        if (collection.totalSupply(tokenId) != 1) {
            revert("can only fractionalize singleton ERC1155 collections");
        }
        if (collection.balanceOf(msg.sender, tokenId) != 1) {
            revert("only owner can initialize fractions");
        }

        fractionId = uint256(keccak256(abi.encodePacked(msg.sender, collection, tokenId)));

        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionId].collection) != address(0)) {
            revert("token is already fractionalized");
        }

        fractionalized[fractionId] = Fractionalized(collection, tokenId, fractionsAmount, _msgSender(), agreementHash, 0);

        _mint(_msgSender(), fractionId, fractionsAmount, "");
        //todo: if we want to take a protocol fee, this might be agood point of doing so.

        //alternatively: transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        //collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");
        emit FractionsCreated(collection, tokenId, originalOwner, fractionId, agreementHash);
    }

    function increaseFractions(uint256 fractionId, uint256 fractionsAmount) external {
        Fractionalized memory _fractionalized = fractionalized[fractionId];

        if (_msgSender() != _fractionalized.originalOwner) {
            revert("only the original owner can update the distribution scheme");
        }
        if (_fractionalized.fulfilledListingId != 0) {
            revert("can't increase fraction shares of an item that's already been sold");
        }
        fractionalized[fractionId].totalIssued += fractionsAmount;
        _mint(_fractionalized.originalOwner, fractionId, fractionsAmount, "");
    }

    /**
     * @dev since we gate this with `onlyDispatcher`, we can assume that L1 has checked that the trade has actually occurred.
     */
    //function afterSale(uint256 listingId, uint256 fractionId) public {
    function afterSale(uint256 fractionId, address paymentToken, uint256 paidPrice) public {
        Fractionalized storage frac = fractionalized[fractionId];
        if (frac.fulfilledListingId != 0) {
            revert("Withdrawal phase already initiated");
        }

        //todo: this is a deep dependency on our own sales contract
        //we alternatively could have the token owner transfer the proceeds and announce the claims to be withdrawable
        (IERC1155Supply tokenContract, uint256 tokenId,,,,, address beneficiary, ListingState listingState) = schmackoSwap.listings(listingId);
        if (listingState != ListingState.FULFILLED) {
            revert("listing is not fulfilled");
        }
        if (tokenContract != frac.collection || tokenId != frac.tokenId) {
            revert("listing doesnt refer to fraction");
        }
        if (beneficiary != address(this)) {
            revert("listing didnt payout fractionalizer");
        }

        // if (paymentToken.balanceOf(address(this)) < askPrice) {
        //     //todo: this is warning, we still could proceed, since it's too late here anyway ;)
        //     revert("the fulfillment doesn't match the ask");
        // }
        frac.fulfilledListingId = listingId;
        frac.paymentToken = IERC20(paymentToken);
        frac.paidPrice = paidPrice;
        emit SalesActivated(fractionId, paymentToken, paidPrice);
    }

    function claimableTokens(uint256 fractionId, address tokenHolder) public view returns (IERC20 paymentToken, uint256 amount) {
        uint256 balance = balanceOf(tokenHolder, fractionId);

        if (fractionalized[fractionId].fulfilledListingId == 0) {
            revert("claiming not available (yet)");
        }

        (,,,, IERC20 _paymentToken, uint256 askPrice,,) = schmackoSwap.listings(fractionalized[fractionId].fulfilledListingId);

        //todo: check this 10 times:
        return (_paymentToken, balance * (askPrice / fractionalized[fractionId].totalIssued));
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

        (IERC20 paymentToken, uint256 erc20shares) = claimableTokens(fractionId, _msgSender());
        if (erc20shares == 0) {
            revert("shares are 0");
        }

        _burn(_msgSender(), fractionId, balance);
        paymentToken.transfer(_msgSender(), erc20shares);
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
        bytes32 termsHash = keccak256(bytes(specificTermsV1(fractionId)));
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
        //signedTerms[fractionId][_msgSender()] = true;
        emit TermsAccepted(fractionId, _msgSender());
    }
    // function supportsInterface(bytes4 interfaceId) public view virtual override (ERC1155ReceiverUpgradeable, ERC1155Upgradeable) returns (bool) {
    //     return super.supportsInterface(interfaceId);
    // }

    // function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external pure returns (bytes4) {
    //     return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    // }

    // function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data)
    //     external
    //     pure
    //     returns (bytes4)
    // {
    //     return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { FractionalizedTokenUpgradeable } from "./FractionalizedToken.sol";

import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";
import { IPNFT } from "./IPNFT.sol";

struct Fractionalized {
    uint256 tokenId;
    //needed to remember an individual's share after others burn their tokens
    uint256 totalIssued;
    address originalOwner;
    string agreementCid;
    FractionalizedTokenUpgradeable tokenContract; //the erc20 token contract representing the fractions
    uint256 fulfilledListingId;
    IERC20 paymentToken;
    uint256 paidPrice;
}

error ToZeroAddress();
error InsufficientBalance();
error TermsNotAccepted();
error InvalidSignature();

/// @title Fractionalizer
/// @author molecule.to
/// @notice
contract Fractionalizer is UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    event FractionsCreated(
        uint256 indexed fractionId, uint256 indexed tokenId, address indexed tokenContract, address emitter, uint256 amount, string agreementCid
    );
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

    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft, SchmackoSwap _schmackoSwap) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();

        ipnft = _ipnft;
        schmackoSwap = _schmackoSwap;
    }

    modifier notClaiming(uint256 fractionId) {
        if (address(fractionalized[fractionId].paymentToken) != address(0)) {
            revert("already in claiming phase");
        }
        _;
    }

    constructor() {
        tokenImplementation = address(new FractionalizedTokenUpgradeable());
        _disableInitializers();
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        if (_feeReceiver == address(0)) {
            revert ToZeroAddress();
        }
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) external onlyOwner {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    function balanceOf(address owner, uint256 fractionId) public view returns (uint256) {
        return fractionalized[fractionId].tokenContract.balanceOf(owner);
    }

    function totalSupply(uint256 fractionId) public view returns (uint256) {
        return fractionalized[fractionId].tokenContract.totalSupply();
    }

    /**
     * @notice
     * @param ipnftId          uint256  the token id on the origin collection
     * @param fractionsAmount  uint256  the initial amount of fractions issued
     * @param agreementCid    bytes32  a content hash that identifies the terms underlying the issued fractions
     */

    function fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid) external returns (uint256 fractionId) {
        if (ipnft.totalSupply(ipnftId) != 1) {
            revert("IPNFT supply must be 1");
        }
        if (ipnft.balanceOf(_msgSender(), ipnftId) != 1) {
            revert("only owner can initialize fractions");
        }

        fractionId = uint256(keccak256(abi.encodePacked(_msgSender(), ipnftId)));

        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionId].originalOwner) != address(0)) {
            revert("token is already fractionalized");
        }

        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        FractionalizedTokenUpgradeable fractionalizedToken = FractionalizedTokenUpgradeable(Clones.clone(tokenImplementation));
        (fractionalizedToken).initialize(
            string(abi.encode("Fractions of IPNFT #", Strings.toString(ipnftId))), string(abi.encode(ipnft.symbol(ipnftId), "-FAM"))
        );

        fractionalized[fractionId] =
            Fractionalized(ipnftId, fractionsAmount, _msgSender(), agreementCid, fractionalizedToken, 0, IERC20(address(0)), 0);

        //todo: if we want to take a protocol fee, this might be agood point of doing so.

        //alternatively: transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        //collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");

        fractionalizedToken.issue(_msgSender(), fractionsAmount);
        emit FractionsCreated(fractionId, ipnftId, address(fractionalizedToken), _msgSender(), fractionsAmount, agreementCid);
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
        _fractionalized.tokenContract.issue(_msgSender(), fractionsAmount);
    }

    /**
     * @notice When the sales beneficiary has not been set to this contract, but to the beneficiary's wallet instead,
     *         they can invoke this method to start the claiming phase manually. This e.g. allows sales off the record.
     *
     *         Requires the originalOwner to behave honestly / in favor of the fraction holders
     *         Requires the caller to have approved `price` of `paymentToken` to this contract
     *
     * @param   fractionId    uint256  the fraction id
     * @param   paymentToken  IERC20   the paymen token contract address
     * @param   price         uint256  the price the NFT has been sold for.
     */
    function afterSale(uint256 fractionId, IERC20 paymentToken, uint256 price) external {
        Fractionalized storage frac = fractionalized[fractionId];
        if (_msgSender() != frac.originalOwner) {
            revert("only the original owner may initialize the sale phase manually");
        }

        //create a fake (but valid) schmackoswap listing id
        frac.fulfilledListingId = uint256(
            keccak256(
                abi.encodePacked(address(ipnft), frac.tokenId, paymentToken, uint256(1), price, address(this), ListingState.FULFILLED, block.number)
            )
        );

        paymentToken.safeTransferFrom(_msgSender(), address(this), price);
        _startSalesPhase(fractionId, paymentToken, price);
    }

    /**
     * @notice When the sales beneficiary has been set to this contract,
     *         anyone can call this function after having observed the sale
     *         to activate the share payout phase on L2
     *
     * @param fractionId    uint256     the unique fraction id
     * @param listingId     uint256     the listing id on Schmackoswap
     */
    function afterSale(uint256 fractionId, uint256 listingId) external {
        Fractionalized storage frac = fractionalized[fractionId];
        if (frac.fulfilledListingId != 0) {
            revert("Withdrawal phase already initiated");
        }

        //todo: this is a deep dependency on our own sales contract
        //we alternatively could have the token owner transfer the proceeds and announce the claims to be withdrawable
        //but they oc could do that on L2 directly...
        (, uint256 tokenId,,, IERC20 _paymentToken, uint256 askPrice, address beneficiary, ListingState listingState) =
            schmackoSwap.listings(listingId);

        if (listingState != ListingState.FULFILLED) {
            revert("listing is not fulfilled");
        }
        if (tokenId != frac.tokenId) {
            revert("listing doesnt refer to the fractionalized nft");
        }
        if (beneficiary != address(this)) {
            revert("listing didnt payout the fractionalizer");
        }

        //todo: this is a warning, we still could proceed, since it's too late here anyway ;)
        // if (paymentToken.balanceOf(address(this)) < askPrice) {
        //     revert("the fulfillment doesn't match the ask");
        // }
        frac.fulfilledListingId = listingId;
        _startSalesPhase(fractionId, _paymentToken, askPrice);
    }

    function _startSalesPhase(uint256 fractionId, IERC20 _paymentToken, uint256 price) internal {
        Fractionalized storage frac = fractionalized[fractionId];
        // if (paymentToken.balanceOf(address(this)) < askPrice) {
        //     //todo: this is warning, we still could proceed, since it's too late here anyway ;)
        //     revert("the fulfillment doesn't match the ask");
        // }
        frac.paymentToken = _paymentToken;
        frac.paidPrice = price;
        emit SalesActivated(fractionId, address(_paymentToken), price);
    }

    function claimableTokens(uint256 fractionId, address tokenHolder) public view returns (IERC20 paymentToken, uint256 amount) {
        Fractionalized memory frac = fractionalized[fractionId];

        if (fractionalized[fractionId].fulfilledListingId == 0) {
            revert("claiming not available (yet)");
        }

        uint256 balance = frac.tokenContract.balanceOf(tokenHolder);

        //todo: check this 10 times:
        return (frac.paymentToken, balance * (frac.paidPrice / frac.totalIssued));
    }

    function burnToWithdrawShare(uint256 fractionId, bytes memory signature) public {
        acceptTerms(fractionId, signature);
        Fractionalized memory frac = fractionalized[fractionId];

        uint256 balance = frac.tokenContract.balanceOf(_msgSender());
        if (balance == 0) {
            revert("you dont own any fractions");
        }

        (IERC20 paymentToken, uint256 erc20shares) = claimableTokens(fractionId, _msgSender());
        if (erc20shares == 0) {
            revert("shares are 0");
        }

        frac.tokenContract.burnFrom(_msgSender(), balance);
        paymentToken.safeTransfer(_msgSender(), erc20shares);
        emit SharesClaimed(fractionId, _msgSender(), balance);
    }

    function specificTermsV1(uint256 fractionId) public view returns (string memory) {
        Fractionalized memory frac = fractionalized[fractionId];

        return string(
            abi.encodePacked(
                "As a fraction holder of IPNFT #",
                Strings.toString(frac.tokenId),
                ", I accept all terms that I've read here: ipfs://",
                frac.agreementCid,
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
        //signedTerms[fractionId][_msgSender()] = true;
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

    function uri(uint256 id) public view returns (string memory) {
        Fractionalized memory frac = fractionalized[id];
        string memory tokenId = Strings.toString(frac.tokenId);

        string memory props = string(
            abi.encodePacked(
                '"properties": {',
                '"ipnft_id": ',
                tokenId,
                ',"agreement_content": "ipfs://',
                frac.agreementCid,
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

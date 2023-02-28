// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

//import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155ReceiverUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1155Supply } from "./IERC1155Supply.sol";

import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

/// @title Fractionalizer
/// @author molecule.to
/// @notice
contract Fractionalizer is ERC1155SupplyUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
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

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractionalized) public fractionalized;
    mapping(uint256 => mapping(address => bool)) public signedTerms;

    modifier onlyBridge () {
        address cdmAddr = getCdmAddr();
        if (cdmAddr == address(0)) {
            revert("this must only be called by the l1l2 bridge");
        }
        _;
    }

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        //not calling the ERC1155 initializer, since we don't need an URI
    }

    function setFeeReceiver(address _feeReceiver) public {
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) external {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    /**
     * @param fractionId the fractionalized token id as computed on the l1 network
     */
    function fractionalizeUniqueERC1155(uint256 fractionId, address collection, uint256 tokenId, bytes32 agreementHash, uint256 fractionsAmount)
        public
        onlyBridge
        returns (uint256)
    {
        // If it is a cross domain message, find out where it is from
        address txL1OriginAddr = ICrossDomainMessenger(cdmAddr).xDomainMessageSender();

        if (uint256(keccak256(abi.encodePacked(txL1OriginAddr, collection, tokenId))) != fractionId) {
            revert("only the owner may fractionalize on the collection")
        }

        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionId].collection) != address(0)) {
            revert("token is already fractionalized");
        }

        fractionalized[fractionId] = Fractionalized(collection, tokenId, fractionsAmount, txL1OriginAddr, agreementHash, address(0), 0);

        _mint(txL1OriginAddr, fractionId, fractionsAmount, "");
        //todo: if we want to take a protocol fee, this might be agood point of doing so.
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

    function afterSale(uint256 fractionId, address paymentToken, uint256 paidPrice) public onlyBridge {

        Fractionalized storage frac = fractionalized[fractionId];
        if (frac.fulfilledListingId != 0) {
            revert("Withdrawal phase already initiated");
        }

        address txL1OriginAddr = ICrossDomainMessenger(cdmAddr).xDomainMessageSender();
        //todo: this should be enforced by the dispatcher contract
        if (txL1OriginAddr != frac.originalOwner) {
            revert("only callable by original owner");
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
        frac.paymentToken = paymentToken;
        frac.paidPrice = paidPrice;
    }

    function claimableTokens(uint256 fractionId, address tokenHolder) public view returns (IERC20 paymentToken, uint256 amount) {
        Fractionalized storage frac = fractionalized[fractionId];

        if (frac.paymentToken == address(0) || frac.paidPrice == 0) {
            revert("claiming not available (yet)");
        }

        uint256 balance = balanceOf(tokenHolder, fractionId);
        //todo: check this 10 times:
        return (frac.paymentToken, balance * (frac.paidPrice / frac.totalIssued));
    }

    function burnToWithdrawShare(uint256 fractionId, uint8 v, bytes32 r, bytes32 s) public {
        acceptTerms(fractionId, v, r, s);
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

    function signedBy(uint256 fractionId, uint8 v, bytes32 r, bytes32 s) public view returns (address) {
        bytes32 termsHash = keccak256(bytes(specificTermsV1(fractionId)));
        return ecrecover(termsHash, v, r, s);
    }

    //todo make this eip1271 compatible
    function acceptTerms(uint256 fractionId, uint8 v, bytes32 r, bytes32 s) public {
        address signer = signedBy(fractionId, v, r, s);
        //todo discuss whether only the signer himself should be able to call this
        // if (signedBy != _msgSender()) {
        //     revert("you're not the one who signed the terms");
        // }
        signedTerms[fractionId][signer] = true;
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

    // Get the cross domain messenger address, if any
    function getCdmAddress() private view returns (address) {
        // Get the cross domain messenger's address each time.
        // This is less resource intensive than writing to storage.
        address cdmAddr = address(0);

        // Mainnet
        if (block.chainid == 1) {
            cdmAddr = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
        }

        // Goerli
        if (block.chainid == 5) {
            cdmAddr = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;
        }

        // L2 (same address on every network)
        if (block.chainid == 10 || block.chainid == 420) {
            cdmAddr = 0x4200000000000000000000000000000000000007;
        }

        // If this isn't a cross domain message
        if (msg.sender != cdmAddr) {
            return address(0);
        }
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

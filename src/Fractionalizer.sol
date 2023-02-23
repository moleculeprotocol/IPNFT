// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

//import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155ReceiverUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1155Supply } from "./IERC1155Supply.sol";

import { IPNFT } from "./IPNFT.sol";
import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";

/// @title Fractionalizer
/// @author molecule.to
/// @notice
contract Fractionalizer is ERC1155SupplyUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    struct Withdrawal {
        uint256 listingId;
        IERC20 paymentToken;
        uint256 tokenAmount;
    }

    struct Fractionalized {
        IERC1155Supply collection;
        uint256 tokenId;
        //needed to remember an individual's share after others burn their tokens
        uint256 totalIssued;
        address originalOwner;
        bytes32 agreementHash;
    }

    //uint256 stillAvailable;

    //    struct Claim { }

    IPNFT ipnft;
    //SchmackoSwap schmackoSwap;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractionalized) public fractionalized;
    mapping(uint256 => uint256) public listings;
    mapping(address => mapping(uint256 => uint256)) claimAllowance;
    mapping(uint256 => Withdrawal) withdrawals;

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

    function fractionalizeUniqueERC1155(IERC1155Supply collection, uint256 tokenId, bytes32 agreementHash, uint256 fractionsAmount)
        external
        returns (uint256 fractionId)
    {
        if (collection.totalSupply(tokenId) != 1) {
            revert("can only fractionalize singleton ERC1155 collections");
        }
        //todo ensure we can only call this once per sales cycle
        if (collection.balanceOf(msg.sender, tokenId) != 1) {
            revert("only owner can initialize fractions");
        }

        //todo: ensure that collection supports the IERC1155Supply interface or adapt Schmackoswap
        fractionId = uint256(keccak256(abi.encodePacked(collection, tokenId)));

        fractionalized[fractionId] = Fractionalized(collection, tokenId, fractionsAmount, _msgSender(), agreementHash);

        _mint(_msgSender(), fractionId, fractionsAmount, "");
        //todo: if we want to take a protocol fee, this might be agood point of doing so.

        //transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        //collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");
    }

    function increaseFractions(uint256 fractionId, uint256 fractionsAmount) external {
        Fractionalized memory _fractionalized = fractionalized[fractionId];
        if (_msgSender() != _fractionalized.originalOwner) {
            revert("only the original owner can update the distribution scheme");
        }
        fractionalized[fractionId].totalIssued += fractionsAmount;
        _mint(_fractionalized.originalOwner, fractionId, fractionsAmount, "");
    }

    function startWithdrawalsOrCancel(SchmackoSwap schmackoSwap, uint256 fractionId) public {
        uint256 listingId = listings[fractionId];
        (,,,, IERC20 paymentToken, uint256 askPrice,, ListingState listingState) = schmackoSwap.listings(listingId);
        if (listingState == ListingState.CANCELLED) {
            delete listings[fractionId];
        } else if (listingState == ListingState.FULFILLED) {
            if (withdrawals[fractionId].listingId != 0) {
                revert("Withdrawal phase already initiated");
            }
            if (paymentToken.balanceOf(address(this)) < askPrice) {
                //todo: this is warning, we still could proceed, since it's too late here anyway ;)
                revert("the fulfillment doesn't match the ask");
            }
            withdrawals[fractionId] = Withdrawal(listingId, paymentToken, askPrice);
        }
    }

    function burnToWithdrawShare(uint256 fractionId) public {
        uint256 balance = balanceOf(_msgSender(), fractionId);
        if (balance == 0) {
            revert("you dont own that many fractions");
        }
        Withdrawal memory withdrawal = withdrawals[fractionId];
        if (withdrawals[fractionId].listingId == 0) {
            revert("no withdrawals available");
        }

        //todo: check this 10 times:
        uint256 erc20rate = balance * (withdrawal.tokenAmount / fractionalized[fractionId].totalIssued);
        _burn(_msgSender(), fractionId, balance);
        withdrawal.paymentToken.transferFrom(address(this), _msgSender(), erc20rate);
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
}

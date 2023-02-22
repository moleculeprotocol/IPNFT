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
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Withdrawal {
        uint256 listingId;
        IERC20 paymentToken;
        uint256 tokenAmount;
    }

    struct Fractionalized {
        IERC1155Supply collection;
        uint256 tokenId;
        uint256 totalIssued;
        address originalOwner;
        bytes32 agreementHash;
    }

    //uint256 stillAvailable;

    //    struct Claim { }

    IPNFT ipnft;
    //SchmackoSwap schmackoSwap;

    CountersUpgradeable.Counter private _fractionalizationCounter;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractionalized) fractionalized;
    mapping(address => mapping(uint256 => uint256)) claimAllowance;
    mapping(uint256 => uint256) listings;
    mapping(uint256 => Withdrawal) withdrawals;

    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        //not calling the ERC1155 initializer, since we don't need an URI

        _fractionalizationCounter.increment();
    }

    function setFeeReceiver(address _feeReceiver) public {
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) external {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    function fractionalizeUniqueERC1155(IERC1155Supply collection, uint256 tokenId, bytes32 agreementHash, uint256 fractionsAmount) external {
        if (collection.totalSupply(tokenId) != 1) {
            revert("can only fractionalize singleton ERC1155 collections");
        }
        //todo ensure we can only call this once per sales cycle
        if (collection.balanceOf(msg.sender, tokenId) != 1) {
            revert("only owner can initialize fractions");
        }

        //todo: ensure that collection supports the IERC1155Supply interface or adapt Schmackoswap
        uint256 fractionId = _fractionalizationCounter.current();
        _fractionalizationCounter.increment();
        fractionalized[fractionId] = Fractionalized(collection, tokenId, fractionsAmount, _msgSender(), agreementHash);

        _mint(address(this), fractionId, fractionsAmount, "");
        //todo: if we want to take a protocol fee, this might be agood point of doing so.

        //transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");
    }

    function increaseFractions(uint256 fractionId, uint256 fractionsAmount) external {
        Fractionalized memory _fractionalized = fractionalized[fractionId];
        if (_msgSender() != _fractionalized.originalOwner) {
            revert("only the original owner can update the distribution scheme");
        }

        _mint(address(this), fractionId, fractionsAmount, "");
    }

    function setupClaims(uint256 fractionId, address[] memory recipients, uint256[] memory amounts) external {
        if (recipients.length != amounts.length) {
            revert("recipients and shares must have the same length");
        }

        Fractionalized memory _fractionalized = fractionalized[fractionId];
        if (_msgSender() != _fractionalized.originalOwner) {
            revert("only the original owner can update the distribution scheme");
        }

        uint256 sumAmounts = 0;
        // bool feeReceiverIncluded = false;
        // uint256 serviceShare = (fractionCount / 100) * fractionalizationPercentage;

        for (uint256 i = 0; i < recipients.length; i++) {
            claimAllowance[recipients[i]][fractionId] += amounts[i];
            sumAmounts += claimAllowance[recipients[i]][fractionId];
            // if (recipients[i] == feeReceiver) {
            //     if (shares[i] < serviceShare) {
            //         revert("you must add the service fee");
            //     }
            //     feeReceiverIncluded = true;
            // }
        }
        // if (!feeReceiverIncluded) {
        //     sumAmounts += serviceShare;
        // }

        if (sumAmounts > balanceOf(address(this), fractionId)) {
            revert("not enough shares available");
        }
    }

    function claimFractions(uint256 fractionId, bytes32 acceptedTermsSig) external {
        //if !isValid(agreementHash, acceptedTermsSig) revert
        uint256 claim = claimAllowance[_msgSender()][fractionId];
        if (claim == 0) {
            revert("nothing to claim for you my friend");
        }
        claimAllowance[_msgSender()][fractionId] = 0;
        safeTransferFrom(address(this), _msgSender(), fractionId, claim, "");
    }

    function list(SchmackoSwap schmackoSwap, uint256 fractionId, IERC20 paymentToken, uint256 askPrice) public {
        Fractionalized memory frac = fractionalized[fractionId];
        if (frac.originalOwner != _msgSender()) {
            revert("only the original owner can list for sale");
        }

        if (listings[fractionId] != 0) {
            revert("this token is already listed");
        }

        IERC1155Supply collection = IERC1155Supply(frac.collection);
        collection.setApprovalForAll(address(schmackoSwap), true);

        uint256 listingId = schmackoSwap.list(collection, frac.tokenId, paymentToken, askPrice);
        listings[fractionId] = listingId;
        schmackoSwap.approveListingOperator(listingId, _msgSender(), true);
    }

    function startWithdrawalsOrCancel(SchmackoSwap schmackoSwap, uint256 fractionId) public {
        uint256 listingId = listings[fractionId];
        (,,,, IERC20 paymentToken, uint256 askPrice, ListingState listingState) = schmackoSwap.listings(listingId);
        if (listingState == ListingState.CANCELLED) {
            delete listings[fractionId];
        } else if (listingState == ListingState.FULFILLED) {
            if (withdrawals[fractionId].listingId != 0) {
                revert("Withdrawal phase already initiated");
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

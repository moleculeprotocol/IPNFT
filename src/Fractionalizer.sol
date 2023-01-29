// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155ReceiverUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPNFT } from "./IPNFT.sol";
import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";

/// @title Fractionalizer
/// @author molecule.to
/// @notice
contract Fractionalizer is ERC1155Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Withdrawal {
        uint256 listingId;
        IERC20 paymentToken;
        uint256 tokenAmount;
    }

    struct Fractions {
        address collection;
        uint256 nftId;
        address lockingAccount;
        uint256 issued;
        uint256 stillAvailable;
    }

    IPNFT ipnft;
    SchmackoSwap schmackoSwap;

    CountersUpgradeable.Counter private _fractionalizationCounter;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractions) fractions;
    mapping(uint256 => uint256) listings;
    mapping(uint256 => Withdrawal) withdrawals;

    function initialize(IPNFT ipnft_, SchmackoSwap schmackoSwap_) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        ipnft = ipnft_;
        schmackoSwap = schmackoSwap_;
        _fractionalizationCounter.increment();
    }

    function setFeeReceiver(address _feeReceiver) public {
        feeReceiver = _feeReceiver;
    }

    function setReceiverPercentage(uint256 fractionalizationPercentage_) public {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    function fractionalizeUniqueErc1155(
        ERC1155Supply collection,
        uint256 tokenId,
        uint256 _fractions,
        address[] memory recipients,
        uint256[] memory shares
    ) public {
        if (collection.totalSupply(tokenId) != 1) {
            revert("can only fractionalize singleton ERC1155 collections");
        }
        //todo ensure we can only call this once per sales cycle
        if (collection.balanceOf(msg.sender, tokenId) != 1) {
            revert("only owner can initialize fractions");
        }
        if (recipients.length != shares.length) {
            revert("recipients and shares must have the same length");
        }

        uint256 sumShares = 0;
        bool feeReceiverIncluded = false;
        uint256 serviceShare = (_fractions / 100) * fractionalizationPercentage;

        for (uint256 i = 0; i < recipients.length; i++) {
            sumShares += shares[i];
            if (recipients[i] == feeReceiver) {
                if (shares[i] < serviceShare) {
                    revert("you must add the service fee");
                }
                feeReceiverIncluded = true;
            }
        }
        if (!feeReceiverIncluded) {
            sumShares += serviceShare;
        }

        if (sumShares > _fractions) {
            revert("you cannot share more than you mint");
        }
        uint256 fractionId = _fractionalizationCounter.current();
        _fractionalizationCounter.increment();
        fractions[fractionId] = Fractions(address(collection), tokenId, _msgSender(), sumShares, sumShares);

        for (uint256 i = 0; i < recipients.length; i++) {
            //todo test overflow
            _mint(recipients[i], fractionId, shares[i], "");
        }
        if (!feeReceiverIncluded) {
            _mint(feeReceiver, fractionId, serviceShare, "");
        }
        if (sumShares < _fractions) {
            _mint(address(this), fractionId, _fractions - sumShares, "");
        }

        //transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");
    }

    function issueSpareFractions(uint256 fractionId, address recipient, uint256 amount) public {
        if (balanceOf(address(this), fractionId) < amount) {
            revert("we don't have that many fractions left");
        }

        Fractions memory frac = fractions[fractionId];
        if (frac.lockingAccount != _msgSender()) {
            revert("can only be called by the original owner");
        }

        safeTransferFrom(address(this), recipient, fractionId, amount, "");
    }

    function list(uint256 fractionId, IERC20 paymentToken, uint256 askPrice) public {
        Fractions memory frac = fractions[fractionId];
        if (frac.lockingAccount != _msgSender()) {
            revert("only the original owner can list for sale");
        }

        ERC1155Supply collection = ERC1155Supply(frac.collection);
        collection.setApprovalForAll(address(schmackoSwap), true);
        uint256 listingId = schmackoSwap.list(collection, frac.nftId, paymentToken, askPrice);
        listings[fractionId] = listingId;
        schmackoSwap.approveListingOperator(listingId, _msgSender(), true);
    }

    function updateListingState(uint256 fractionId) public {
        uint256 listingId = listings[fractionId];
        (,,,, IERC20 paymentToken, uint256 askPrice, ListingState listingState) = schmackoSwap.listings(listingId);
        if (listingState == ListingState.CANCELLED) {
            delete listings[fractionId];
        } else if (listingState == ListingState.FULFILLED) {
            withdrawals[fractionId] = Withdrawal(listingId, paymentToken, askPrice);
        }
    }

    function burnToWithdrawShare(uint256 fractionId, uint256 amount) public {
        if (balanceOf(_msgSender(), fractionId) < amount) {
            revert("you dont own that many fractions");
        }
        Withdrawal memory withdrawal = withdrawals[fractionId];

        uint256 erc20share = amount * (withdrawal.tokenAmount / fractions[fractionId].issued);
        _burn(_msgSender(), fractionId, amount);
        withdrawal.paymentToken.transferFrom(address(this), _msgSender(), erc20share);
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

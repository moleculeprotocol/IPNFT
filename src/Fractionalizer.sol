// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPNFT } from "./IPNFT.sol";
import { SchmackoSwap } from "./SchmackoSwap.sol";

/// @title Fractionalizer
/// @author molecule.to
/// @notice
contract Fractionalizer is ERC1155Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Withdrawal {
        uint256 listingId;
        uint256 tokenId;
        IERC20 paymentToken;
        uint256 tokenAmount;
    }

    struct Fractions {
        uint256 nftId;
        uint256 issued;
        uint256 stillAvailable;
    }

    IPNFT ipnft;
    SchmackoSwap schmackoSwap;

    CountersUpgradeable.Counter private _fractionalizationCounter;

    address feeReceiver;
    uint256 fractionalizationPercentage;

    mapping(uint256 => Fractions) fractions;
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

    function fractionalize(uint256 ipnftId, uint256 _fractions, address[] memory recipients, uint256[] memory shares) public {
        //todo ensure we can only call this once per sales cycle
        if (ipnft.balanceOf(msg.sender, ipnftId) != 1) {
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
        fractions[fractionId] = Fractions(ipnftId, sumShares, sumShares);

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
    }

    function issueLockedFractions(uint256 fractionId, address recipient, uint256 amount) public {
        if (balanceOf(address(this), fractionId) < amount) {
            revert("we don't have that much fractions left");
        }

        Fractions memory frac = fractions[fractionId];

        if (ipnft.balanceOf(msg.sender, frac.nftId) != 1) {
            revert("only ipnft owner can initialize fractions");
        }

        safeTransferFrom(address(this), recipient, fractionId, amount, "");
    }

    function list(uint256 tokenId, IERC20 paymentToken, uint256 askPrice) public {
        //todo this cant work because we're not owning the token.
        schmackoSwap.list(ERC1155Supply(address(ipnft)), tokenId, paymentToken, askPrice);
    }

    function fulfill(uint256 listingId) public {
        (, uint256 ipnftId, address creator,, IERC20 paymentToken, uint256 askPrice) = schmackoSwap.listings(listingId);
        if (creator != address(this)) {
            revert("this is not a fractionalized sales listing");
        }

        withdrawals[ipnftId] = Withdrawal(listingId, ipnftId, paymentToken, askPrice);
        schmackoSwap.fulfill(listingId);
    }

    function burnAndWithdrawShare(uint256 fractionId, uint256 amount) public {
        if (balanceOf(msg.sender, fractionId) < amount) {
            revert("you dont own that many fractions");
        }
        Withdrawal memory withdrawal = withdrawals[fractionId];
        if (withdrawal.tokenId == 0) {
            revert("no withdrawals for this tokenid");
        }

        uint256 erc20share = amount * (withdrawal.tokenAmount / fractions[fractionId].issued);
        _burn(msg.sender, fractionId, amount);
        withdrawal.paymentToken.transferFrom(address(this), msg.sender, erc20share);
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

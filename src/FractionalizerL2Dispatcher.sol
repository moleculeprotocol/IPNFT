// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC1155Supply } from "./IERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";
import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";
import { ContractRegistry } from "./ContractRegistry.sol";

contract FractionalizerL2Dispatcher {
    struct Fractionalized {
        IERC1155Supply collection;
        uint256 tokenId;
        address originalOwner;
        uint256 fulfilledListingId;
    }

    ContractRegistry registry;
    SchmackoSwap schmackoSwap;

    mapping(uint256 => Fractionalized) public fractionalized;

    constructor(SchmackoSwap _schmackoSwap, ContractRegistry _registry) {
        schmackoSwap = _schmackoSwap;
        registry = _registry;
    }

    function initializeFractionalization(IERC1155Supply collection, uint256 tokenId, bytes32 agreementHash, uint256 fractionsAmount)
        external
        returns (uint256)
    {
        if (collection.totalSupply(tokenId) != 1) {
            revert("can only fractionalize ERC1155 tokens with a supply of 1");
        }

        if (collection.balanceOf(msg.sender, tokenId) != 1) {
            revert("only owner can initialize fractions");
        }

        uint256 fractionId = uint256(keccak256(abi.encodePacked(msg.sender, collection, tokenId)));
        fractionalized[fractionId] = Fractionalized(collection, tokenId, msg.sender, 0);

        bytes memory message =
            abi.encodeWithSignature("fractionalizeUniqueERC1155(uint256,bytes32,uint256)", fractionId, agreementHash, fractionsAmount);

        //alternatively: transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        //collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");

        address crossDomainMessengerAddr = registry.safeGet("CrossdomainMessenger");
        ICrossDomainMessenger(crossDomainMessengerAddr).sendMessage(
            registry.safeGet("FractionalizerL2"),
            message,
            1_000_000 // within the free gas limit amount
        );
        return fractionId;
    }

    /// @notice Anyone can call this once they observe the sale to activate the share payout phase
    function afterSale(uint256 fractionId, uint256 listingId) external {
        Fractionalized storage frac = fractionalized[fractionId];
        if (frac.fulfilledListingId != 0) {
            revert("Withdrawal phase already initiated");
        }

        //todo: this is a deep dependency on our own sales contract
        //we alternatively could have the token owner transfer the proceeds and announce the claims to be withdrawable
        //but they oc could do that on L2 directly...
        (IERC1155Supply tokenContract, uint256 tokenId,,, IERC20 _paymentToken, uint256 askPrice, address beneficiary, ListingState listingState) =
            schmackoSwap.listings(listingId);

        if (listingState != ListingState.FULFILLED) {
            revert("listing is not fulfilled");
        }
        if (tokenContract != frac.collection || tokenId != frac.tokenId) {
            revert("listing doesnt refer to the fractionalized nft");
        }
        if (beneficiary != address(this)) {
            revert("listing didnt payout the fractionalizer");
        }

        //todo: this is warning, we still could proceed, since it's too late here anyway ;)
        // if (paymentToken.balanceOf(address(this)) < askPrice) {
        //     revert("the fulfillment doesn't match the ask");
        // }
        frac.fulfilledListingId = listingId;

        //bridge ERC20 to L2, right here
        //https://community.optimism.io/docs/developers/bridge/standard-bridge/#
        address bridgeAddr = registry.safeGet("StandardBridge");
        address crossDomainMessengerAddr = registry.safeGet("CrossdomainMessenger");
        address fractionalizerAddrL2 = registry.safeGet("FractionalizerL2");
        address tokenL2Address = registry.safeGet(address(_paymentToken));

        //todo: the approval should be provided in general.
        if (_paymentToken.allowance(address(this), bridgeAddr) < askPrice) {
            if (!_paymentToken.approve(bridgeAddr, askPrice)) {
                revert("approval failed");
            }
        }

        //good luck figuring the reason for this one out:
        uint32 _minGasLimit = 20_000;
        IL1ERC20Bridge(bridgeAddr).depositERC20To(address(_paymentToken), tokenL2Address, fractionalizerAddrL2, askPrice, _minGasLimit, "");

        //initiate sale on L2
        //todo: the bridged tokens should arrive at L2 first for this to work.
        //calling this from here ensures this is a valid sales phase intitialization
        //on L2 you cannot prove this!
        bytes memory message = abi.encodeWithSignature("afterSale(uint256,address,uint256)", fractionId, address(_paymentToken), askPrice);

        ICrossDomainMessenger(crossDomainMessengerAddr).sendMessage(
            fractionalizerAddrL2,
            message,
            1_000_000 // within the free gas limit amount
        );
    }
}

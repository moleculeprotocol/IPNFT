// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";

import { IERC1155Supply } from "./IERC1155Supply.sol";
import { ContractRegistry } from "./ContractRegistry.sol";
import { SchmackoSwap, ListingState } from "./SchmackoSwap.sol";

contract FractionalizerL2Dispatcher is UUPSUpgradeable, OwnableUpgradeable {
    struct Fractionalized {
        IERC1155Supply collection;
        uint256 tokenId;
        address originalOwner;
        uint256 fulfilledListingId;
    }

    ContractRegistry registry;
    SchmackoSwap schmackoSwap;

    mapping(uint256 => Fractionalized) public fractionalized;

    //good luck figuring the right value for this one:
    //https://community.optimism.io/docs/developers/bridge/messaging/#communication-basics-between-layers
    uint32 constant MIN_GASLIMIT = 1_000_000;

    function initialize(SchmackoSwap _schmackoSwap, ContractRegistry _registry) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();

        schmackoSwap = _schmackoSwap;
        registry = _registry;
    }

    constructor() {
        _disableInitializers();
    }

    function initializeFractionalization(IERC1155Supply collection, uint256 tokenId, bytes32 agreementHash, uint256 fractionsAmount)
        external
        returns (uint256)
    {
        if (collection.totalSupply(tokenId) != 1) {
            revert("can only fractionalize ERC1155 tokens with a supply of 1");
        }

        if (collection.balanceOf(_msgSender(), tokenId) != 1) {
            revert("only owner can initialize fractions");
        }

        uint256 fractionId = uint256(keccak256(abi.encodePacked(_msgSender(), collection, tokenId)));
        fractionalized[fractionId] = Fractionalized(collection, tokenId, _msgSender(), 0);

        bytes memory message = abi.encodeWithSignature(
            "fractionalizeUniqueERC1155(uint256,address,uint256,address,bytes32,uint256)",
            fractionId,
            collection,
            tokenId,
            _msgSender(),
            agreementHash,
            fractionsAmount
        );

        //alternatively: transfer the NFT to Fractionalizer so it can't be transferred while fractionalized
        //collection.safeTransferFrom(_msgSender(), address(this), tokenId, 1, "");

        address crossDomainMessengerAddr = registry.safeGet("CrossdomainMessenger");

        ICrossDomainMessenger(crossDomainMessengerAddr).sendMessage(registry.safeGet("FractionalizerL2"), message, 250_000);
        //MIN_GASLIMIT // within the free gas limit amount

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

        IL1ERC20Bridge(bridgeAddr).depositERC20To(address(_paymentToken), tokenL2Address, fractionalizerAddrL2, askPrice, MIN_GASLIMIT, "");

        //initiate sale on L2
        //todo: the bridged tokens should arrive at L2 first for this to work.
        //calling this from here ensures this is a valid sales phase intitialization
        //on L2 you cannot prove this!
        bytes memory message = abi.encodeWithSignature("afterSale(uint256,address,uint256)", fractionId, address(_paymentToken), askPrice);

        ICrossDomainMessenger(crossDomainMessengerAddr).sendMessage(
            fractionalizerAddrL2,
            message,
            MIN_GASLIMIT // within the free gas limit amount
        );
    }

    /// @dev see UUPSUpgradeable
    function _authorizeUpgrade(address /*newImplementation*/ ) internal override onlyOwner { }
}

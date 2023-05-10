// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { FixedPointMathLib as FP } from "solmate/utils/FixedPointMathLib.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

struct Signal {
    uint184 rate;
    uint64 lastUpdate;
}

struct Meta {
    uint8 decimals;
    bytes32 symbol;
}

interface IPriceFeedConsumer {
    function getPrice(address base, address quote) external view returns (uint184);
}

//the real thing is this: https://docs.chain.link/data-feeds/feed-registry
/**
 * @title BioPriceFeed
 * @author molecule.to
 * @notice lets signallers push prices to chain
 */

contract BioPriceFeed is IPriceFeedConsumer, AccessControl {
    mapping(bytes32 => Signal) signals;
    mapping(bytes32 => Meta) meta;

    bytes32 public constant ROLE_SIGNALLER = keccak256("ROLE_SIGNALLER");

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    // Fiat currencies follow https://en.wikipedia.org/wiki/ISO_4217
    address public constant USD = address(840);
    address public constant GBP = address(826);
    address public constant EUR = address(978);
    address public constant JPY = address(392);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ROLE_SIGNALLER, _msgSender());
    }

    function getPrice(address base, address quote) external view returns (uint184) {
        bytes32 key = keccak256(abi.encode(base, quote));
        if (meta[key].decimals != 0) {
            if (meta[key].decimals > 18) revert("unsupported");
            return uint184(signals[key].rate / 10 ** (18 - meta[key].decimals));
        } else {
            return signals[key].rate;
        }
    }

    function setMetadata(address base, address quote, Meta calldata _meta) external onlyRole(ROLE_SIGNALLER) {
        meta[keccak256(abi.encode(base, quote))] = _meta;
    }

    function signal(address base, address quote, uint184 wadPrice) external onlyRole(ROLE_SIGNALLER) {
        signals[keccak256(abi.encode(base, quote))] = Signal(wadPrice, uint64(block.timestamp));
        signals[keccak256(abi.encode(quote, base))] = Signal(uint184(FP.divWadDown(1e18, wadPrice)), uint64(block.timestamp));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IIPSeedCurve } from "./IIPSeedCurve.sol";
import { UD60x18, ud, convert } from "@prb/math/UD60x18.sol";

contract LinearCurve is IIPSeedCurve {
    function priceAt(UD60x18 supply, UD60x18 steepness) public pure returns (UD60x18) {
        return steepness.mul(supply);
    }

    /**
     * @inheritdoc IIPSeedCurve
     */
    function getBuyPrice(uint256 supply, uint256 want, bytes32 curveParameters) public pure virtual override returns (uint256) {
        UD60x18 steepness = ud(uint256(curveParameters));
        UD60x18 p0 = priceAt(convert(supply), steepness);
        UD60x18 p1 = priceAt(convert(supply + want), steepness);
        UD60x18 two = convert(2);
        UD60x18 result = ud(want).mul(p1.sub((p1.sub(p0)).div(two)));

        return convert(result);
    }

    /**
     * @inheritdoc IIPSeedCurve
     */
    function getSellPrice(uint256 supply, uint256 sell, bytes32 parameters) external pure virtual override returns (uint256) {
        return getBuyPrice(supply - sell, sell, parameters);
    }

    function getTokensForValue(uint256 supply, uint256 amount, bytes32 curveParameters) external pure returns (uint256) { }

    function areParametersInRange(bytes32 curveParameters) external pure override returns (bool) {
        UD60x18 steepness = ud(uint256(curveParameters));
        return (steepness.gte(ud(1e4)) && steepness.lt(ud(1e40)));
    }
}

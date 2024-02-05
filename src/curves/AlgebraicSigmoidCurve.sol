// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
/* solhint-disable no-inline-assembly */

import { IIPSeedCurve } from "./IIPSeedCurve.sol";
import { UD60x18, ud, unwrap, sqrt } from "@prb/math/UD60x18.sol";

/**
 * https://www.desmos.com/calculator/svr7uwajhr
 *
 * @title AlgebraicSigmoidCurve
 * @author stefan@molecule.to
 * @notice computes the prices to place / withdraw collateral on an algebraic sigmoidal bonding curve
 *         uses PRBMath for floating point operations
 */
contract AlgebraicSigmoidCurve is IIPSeedCurve {
    /**
     * computes the collateral function
     *
     * @param x UD60x18 current supply
     * @param a UD60x18
     * @param b UD60x18
     * @param c UD60x18
     *
     * @dev the collateral function C is the defined integral of the price curve. It can be interpreted as accrued capital at a certain price point on the underlying sigmoid
     */
    function collateral(UD60x18 x, UD60x18 a, UD60x18 b, UD60x18 c) private pure returns (uint256) {
        UD60x18 b2plusc = (b.mul(b)).add(c);
        UD60x18 inner = sqrt(((x.mul(x)).add(b2plusc)).sub(ud(2e18).mul(b).mul(x)));
        UD60x18 result = (x.add(inner)).sub(sqrt(b2plusc)).mul(a);

        return unwrap(result);
    }

    /**
     * @param parameters bytes32 encoded function parameters
     * @return a in: uint64 max price / 2 - controls the "funding goal" amount
     * @return b in: uint96 inflection point (2*b = "supply at funding goal")
     * @return c in: uint96 the steepness of price increase
     */
    function decodeParameters(bytes32 parameters) public pure returns (UD60x18 a, UD60x18 b, UD60x18 c) {
        bytes memory _bytes = abi.encodePacked(parameters);
        uint64 _a;
        uint96 _b;
        uint96 _c;

        assembly {
            // Decode the values
            _a := mload(add(_bytes, 8))
            _b := mload(add(_bytes, 20))
            _c := mload(add(_bytes, 32))
        }

        a = ud(uint256(_a) * 1e12);
        b = ud(uint256(_b) * 1e9);
        c = ud(uint256(_c) * 1e9);
    }

    /**
     * @inheritdoc IIPSeedCurve
     */
    function getBuyPrice(uint256 supply, uint256 want, bytes32 curveParameters) public pure virtual override returns (uint256) {
        (UD60x18 a, UD60x18 b, UD60x18 c) = decodeParameters(curveParameters);
        uint256 startPrice = collateral(ud(supply), a, b, c);
        uint256 endPrice = collateral(ud(supply + want), a, b, c);
        return endPrice - startPrice;
    }

    /**
     * @inheritdoc IIPSeedCurve
     */
    function getSellPrice(uint256 supply, uint256 sell, bytes32 curveParameters) external pure virtual override returns (uint256) {
        return getBuyPrice(supply - sell, sell, curveParameters);
    }

    function getTokensForValue(uint256 supply, uint256 amount, bytes32 curveParameters) external pure returns (uint256) {
        //todo implement or drop
        return 0;
    }

    /**
     * @notice ranges are (after decoding):
     * a: [0.00001 ether - 1_000_000_000_000 ether]
     * b: [0.0000001 ether - 10_000_000_000 ether]
     * c: [0.0000001 ether - 10_000_000_000 ether]
     * @param curveParameters bytes32 encoded function parameters
     */
    function areParametersInRange(bytes32 curveParameters) external pure override returns (bool) {
        (UD60x18 a, UD60x18 b, UD60x18 c) = decodeParameters(curveParameters);
        return (a.lte(ud(1e30)) && a.gte(ud(1e14)) && b.lte(ud(1e28)) && b.gte(ud(1e12)) && c.lte(ud(1e28)) && c.gte(ud(1e12)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { console } from "forge-std/console.sol";

/**
 * @title Base32
 * @author stefan@molecule.to
 * @notice adapted from https://github.com/LinusU/base32-encode to solidity.
 * @dev this is neither optimized nor tested correctly
 */
library Base32 {
    bytes constant alphabet = "abcdefghijklmnopqrstuvwxyz234567";

    function encode(bytes memory data) public view returns (bytes memory) {
        uint32 bits = 0;
        uint32 value = 0;
        bytes memory output = "";

        for (uint32 i = 0; i < data.length; i++) {
            value = (value << 8) | uint8(data[i]);
            bits += 8;

            while (bits >= 5) {
                //use unsigned right shift >>>
                output = addByte(output, alphabet[(value >> (bits - 5)) & 31]);
                bits -= 5;
            }
        }

        if (bits > 0) {
            output = addByte(output, alphabet[(value << (5 - bits)) & 31]);
        }

        return output;
    }

    function addByte(bytes memory byteArray, bytes1 newByte) internal pure returns (bytes memory) {
        bytes memory returnArray = new bytes(byteArray.length + 1);
        uint256 i = 0;
        for (i; i < byteArray.length; i++) {
            returnArray[i] = byteArray[i];
        }
        returnArray[byteArray.length] = newByte;
        return returnArray;
    }

    // function to_binary(uint256 x) internal pure returns (bytes memory) {
    //     if (x == 0) {
    //         return new bytes(0);
    //     } else {
    //         bytes1 s = bytes1(uint8(x % 256));
    //         bytes memory r = new bytes(1);
    //         r[0] = s;
    //         return concat(to_binary(x / 256), r);
    //     }
    // }
}

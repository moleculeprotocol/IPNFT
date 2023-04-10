// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Base32
 * @author stefan@molecule.to
 * @notice base32 encodes up to 256 characters, sufficient for ipfs use cases
 * @dev adapted from https://github.com/LinusU/base32-encode to solidity.
 * @dev not intensely tested
 */
library Base32 {
    //RFC4648
    bytes constant alphabet = "abcdefghijklmnopqrstuvwxyz234567";

    function encode(bytes memory data) public pure returns (bytes memory output) {
        require(data.length < 255, "data too large");
        uint16 bits = 0;
        uint16 value = 0;
        bytes memory tmpOut = new bytes(255);
        uint8 outIndex = 0;

        for (uint8 i = 0; i < data.length; i++) {
            value = (value << 8) | uint8(data[i]);
            bits += 8;

            while (bits >= 5) {
                //original uses unsigned right shift >>>
                tmpOut[outIndex++] = alphabet[(value >> (bits - 5)) & 31];
                bits -= 5;
            }
        }

        if (bits > 0) {
            tmpOut[outIndex++] = alphabet[(value << (5 - bits)) & 31];
        }
        output = new bytes(outIndex);
        for (uint8 i = 0; i < outIndex; i++) {
            output[i] = tmpOut[i];
        }
    }
}

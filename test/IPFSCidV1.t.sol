// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
//import { console } from "forge-std/console.sol";
import { IpfsLib } from "../src/IpfsLib.sol";
import { Base32 } from "../src/Base32.sol";

contract IpfsCidV1Test is Test {
    //    bytes32 agreementHash = keccak256(bytes("the binary content of the fraction holder agreeemnt"));
    //bafkreifr6sxrpoayfnplgyahes7r67vujygqvaay2x2skl2hm4wlwazjua
    //f01551220b1f4af17b8182b5eb3600724bf1f7eb44e0d0a8018d5f5252f47672cbb0329a0
    bytes32 agreementHash = 0xb1f4af17b8182b5eb3600724bf1f7eb44e0d0a8018d5f5252f47672cbb0329a0;
    //bytes fullCid = hex"f01551220b1f4af17b8182b5eb3600724bf1f7eb44e0d0a8018d5f5252f47672cbb0329a0";

    function testRecoverCidV1() public {
        //bytes memory _agreementHash = abi.encodePacked(agreementHash);
        //bytes memory _aghB58 = Base58.encode(_agreementHash);
        bytes memory fullHash = hex"01551220b1f4af17b8182b5eb3600724bf1f7eb44e0d0a8018d5f5252f47672cbb0329a0";
        bytes memory aghB32 = Base32.encode(fullHash);
        assertEq(string(aghB32), "afkreifr6sxrpoayfnplgyahes7r67vujygqvaay2x2skl2hm4wlwazjua");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import { Base32 } from "../src/Base32.sol";

contract EncodeCidBase32Test is Test {
    function testEncodeSomeValues() public {
        bytes memory fullHash = hex"01551220b1f4af17b8182b5eb3600724bf1f7eb44e0d0a8018d5f5252f47672cbb0329a0";
        bytes memory aghB32 = Base32.encode(fullHash);
        assertEq(string(aghB32), "afkreifr6sxrpoayfnplgyahes7r67vujygqvaay2x2skl2hm4wlwazjua");

        fullHash = hex"01551220ec0a86a6f8baa907521ae47f82a8c161283d974a8dd93de158ce8fdd80afb1a6";
        assertEq(string(Base32.encode(fullHash)), "afkreihmbkdkn6f2vedvegxep6bkrqlbfa6zosun3e66cwgor7oybl5ruy");

        fullHash = hex"01551220e999ae54973e51a80b74276b680ffbc382b068bc04664193e760a16a2f4d8099";
        assertEq(string(Base32.encode(fullHash)), "afkreihjtgxfjfz6kguaw5bhnnua766dqkygrpaemzazhz3aufvc6tmate");
    }

    //costs 68632 gas
    function testEncodeCIDv1Fragment() public {
        bytes32 cidv1Hash = 0xe999ae54973e51a80b74276b680ffbc382b068bc04664193e760a16a2f4d8099;
        bytes memory prefix = hex"01551220";

        string memory cid = string(abi.encodePacked("b", Base32.encode(abi.encodePacked(prefix, cidv1Hash))));
        assertEq(string(cid), "bafkreihjtgxfjfz6kguaw5bhnnua766dqkygrpaemzazhz3aufvc6tmate");
    }
}

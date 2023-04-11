// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SignTermsMessage is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        string memory terms =
            "As a fraction holder of IPNFT #10, I accept all terms that I've read here: ipfs://bafkreigk5dvqblnkdniges6ft5kmuly47ebw4vho6siikzmkaovq6sjstq\n\nChain Id: 31337\nVersion: 1";

        bytes32 termsHash = ECDSA.toEthSignedMessageHash(abi.encodePacked(terms));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, termsHash);
        bytes memory xsignature = abi.encodePacked(r, s, v);

        console.logBytes(xsignature);
    }
}

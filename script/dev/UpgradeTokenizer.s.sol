// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "forge-std/Script.sol";

import {Tokenizer11} from '../../src/helpers/test-upgrades/Tokenizer11.sol';
import {Tokenizer} from '../../src/Tokenizer.sol';
import { Safe } from "safe-global/safe-contracts/Safe.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";
import { IPToken } from "../../src/IPToken.sol";
contract UpgradeTokenizer11_12 is Script {

    function run() public {
        address proxyGoerli = 0xb12494eeA6B992d0A1Db3C5423BE7a2d2337F58c;
        address gnosisSafe = 0x78AEc76f99acD27AfBFaA65430A7dF9c1c995d8C;
        Tokenizer11 tokenizer11 = Tokenizer11(proxyGoerli);
        Safe safe = Safe(payable(gnosisSafe));

        IPToken newIpTokenImplementation = new IPToken();
        Tokenizer newTokenizerImplementation = new Tokenizer();

        bytes memory upgradeCall = abi.encodeCall(
            tokenizer11.upgradeToAndCall,
            (
                address(newTokenizerImplementation),
                abi.encodeWithSignature("setIPTokenImplementation(address)", address(newIpTokenImplementation))
            )
        );

        bytes32 encodedTxDataHash = safe.getTransactionHash(
            address(tokenizer11),
            0,
            upgradeCall,
            Enum.Operation.Call,
            80_000,
            1 gwei,
            20 gwei,
            address(0x0),
            payable(0x0),
            0
        );
        uint256 signerPkOne = vm.envUint("SIGNER_PK_ONE");
        uint256 signerPkTwo = vm.envUint("SIGNER_PK_TWO");
        (uint8 vi, bytes32 ri, bytes32 si) = safe.sign(signerPkOne, encodedTxDataHash);
        (uint8 vii, bytes32 rii, bytes32 sii) = safe.sign(signerPkOne, encodedTxDataHash);
        bytes memory xsignatures = abi.encodePacked(ri, si, vi, rii, sii, vii);
        safe.execTransaction(
            address(tokenizer11),
            0,
            upgradeCall,
            Enum.Operation.Call,
            80_000,
            1 gwei,
            20 gwei,
            address(0x0),
            payable(0x0),
            xsignatures
        );


    }
}
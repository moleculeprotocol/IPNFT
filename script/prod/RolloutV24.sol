// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { IPermissioner, TermsAcceptedPermissioner } from "../../src/Permissioner.sol";
import { StakedLockingCrowdSale } from "../../src/crowdsale/StakedLockingCrowdSale.sol";
import { SignedMintAuthorizer } from "../../src/SignedMintAuthorizer.sol";
import { Tokenizer } from "../../src/Tokenizer.sol";

/**
 * @title Rollout24
 * @author molecule.to
 * @notice deploys / initializes new contracts and implementations on mainnet
 */
contract RolloutV24 is Script {
    function run() public {
        vm.startBroadcast();
        IPNFT ipnftImpl = new IPNFT();

        //address goerliDefenderRelayer = 0xbCeb6b875513629eFEDeF2A2D0b2f2a8fd2D4Ea4;
        address mainnetDefenderRelayer = 0x3D30452c48F2448764d5819a9A2b684Ae2CC5AcF;
        SignedMintAuthorizer authorizer = new SignedMintAuthorizer(mainnetDefenderRelayer);
        TermsAcceptedPermissioner permissioner = new TermsAcceptedPermissioner();
        Tokenizer tokenizerImpl = new Tokenizer();
        vm.stopBroadcast();

        console.log("SIGNED_MINT_AUTHORIZER=%s", address(authorizer));
        console.log("TERMS_ACCEPTED_PERMISSIONER_ADDRESS=%s", address(permissioner));
        console.log("new ipnft impl: %s", address(ipnftImpl));
        console.log("new tokenizer impl: %s", address(tokenizerImpl));
    }
}

/*
    //multisig: Upgrade IPNFT to 2.4 / set new authorizer
    // 0xcaD88677CA87a7815728C72D74B4ff4982d54Fc1 //the IPNFT proxy
    ipnft.upgradeTo(address(ipnftImpl))
    //set new authorizer on current IPNFT contract:
    ipnft.setAuthorizer(authorizer);
*/

/*
 //upgrade Synthesizer -> Tokenizer using multisig
 
 //0x58EB89C69CB389DBef0c130C6296ee271b82f436 //that's the synthesizer mainnet proxy
 synthesizer.upgradeTo(address(tokenizerImpl));
 
 // now, it's a Tokenizer
 Tokenizer tokenizer = Tokenizer(0x58EB89C69CB389DBef0c130C6296ee271b82f436);
 tokenizer.reinit(newTermsPermissioner);     

> forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/Permissioner.sol:TermsAcceptedPermissioner --etherscan-api-key $ETHERSCAN_API_KEY --verify

*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;
import "forge-std/Script.sol";
import "../src/IPToken.sol";
//import "forge-std/console.sol";

//import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployIPTokenImpl is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IPToken iptoken = new IPToken();

        //NFT nft = new NFT("NFT_tutorial", "TUT", "baseUri");

        vm.stopBroadcast();
    }
}
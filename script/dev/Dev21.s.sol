// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { MyToken } from "../../src/MyToken.sol";
import { IPNFT } from "../../src/IPNFT.sol";
import { IPNFTV21 } from "../../src/IPNFTV21.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { AuthorizeAll } from "../../src/helpers/AuthorizeAll.sol";
import { IAuthorizeMints } from "../../src/IAuthorizeMints.sol";
import { UUPSProxy } from "../../src/UUPSProxy.sol";
import { Mintpass } from "../../src/Mintpass.sol";

/*
forge script --rpc-url $RPC_URL script/dev/Dev21.s.sol:DeployIpnftV21 -vvvv --broadcast
forge script --rpc-url $RPC_URL script/dev/Dev21.s.sol:Reserve -vvvv --broadcast
forge script --rpc-url $RPC_URL script/dev/Dev21.s.sol:Reserve -vvvv --broadcast
RESERVATION=1 forge script --rpc-url $RPC_URL script/dev/Dev21.s.sol:MintV21 -vvvv --broadcast

then
forge script --rpc-url $RPC_URL script/dev/Dev21.s.sol:UpgradeIpnftV22 -vvvv --broadcast
RESERVATION=2 forge script --rpc-url $RPC_URL script/dev/Dev21.s.sol:MintV22 -vvvv --broadcast

cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "uri(uint256)" 1 | cast --to-ascii
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "uri(uint256)" 2 | cast --to-ascii

cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "symbol(uint256)" 1 | cast --to-ascii
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "symbol(uint256)" 2 | cast --to-ascii*/

contract DeployIpnftV21 is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address deployer,) = deriveRememberKey(mnemonic, 0);
        vm.startBroadcast(deployer);
        IPNFTV21 implementationV21 = new IPNFTV21();
        UUPSProxy proxy = new UUPSProxy(address(implementationV21), "");
        IPNFTV21 ipnft = IPNFTV21(address(proxy));
        ipnft.initialize();

        //only here to have addresses for subgraph in place
        SchmackoSwap swap = new SchmackoSwap();
        MyToken token = new MyToken();
        Mintpass mintpass = new Mintpass(address(ipnft));

        ipnft.setAuthorizer(address(new AuthorizeAll()));

        console.log("ipnftv21 %s", address(ipnft));
        console.log("swap %s", address(swap));
        console.log("token %s", address(token));
        console.log("pass %s", address(mintpass));

        vm.stopBroadcast();
    }
}

contract UpgradeIpnftV22 is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address deployer,) = deriveRememberKey(mnemonic, 0);
        vm.startBroadcast(deployer);
        IPNFT implementationV22 = new IPNFT();
        IPNFT ipnftV22 = IPNFT(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        ipnftV22.upgradeTo(address(implementationV22));

        vm.stopBroadcast();
    }
}

contract Reserve is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address owner,) = deriveRememberKey(mnemonic, 1);

        vm.startBroadcast(owner);
        IPNFTV21 ipnft = IPNFTV21(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        uint256 reservationId = ipnft.reserve();
        vm.stopBroadcast();

        console.log("Reservation Id: %s", reservationId);
    }
}

contract MintV21 is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address owner,) = deriveRememberKey(mnemonic, 1);
        uint256 reservationId = vm.envUint("RESERVATION");

        vm.startBroadcast(owner);
        IPNFTV21 ipnft = IPNFTV21(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        ipnft.mintReservation{ value: 0.001 ether }(owner, reservationId, 0, "ipfs://tokenURI");
        vm.stopBroadcast();
    }
}

contract MintV22 is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    function run() public {
        (address owner,) = deriveRememberKey(mnemonic, 1);
        uint256 reservationId = vm.envUint("RESERVATION");

        vm.startBroadcast(owner);
        IPNFT ipnft = IPNFT(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
        ipnft.mintReservation{ value: 0.001 ether }(owner, reservationId, 0, "ipfs://tokenURI/V22", "SYMBOL-00001");
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { FakeERC20 } from "../../src/helpers/FakeERC20.sol";
import { SchmackoSwap } from "../../src/SchmackoSwap.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ApproveAndBuy is Script {
    string mnemonic = "test test test test test test test test test test test junk";

    SchmackoSwap schmackoSwap;
    FakeERC20 erc20;

    address deployer;
    address bob;
    address alice;

    function prepareAddresses() internal {
        (deployer,) = deriveRememberKey(mnemonic, 0);
        (bob,) = deriveRememberKey(mnemonic, 1);
        (alice,) = deriveRememberKey(mnemonic, 2);
        schmackoSwap = SchmackoSwap(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
        erc20 = FakeERC20(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    }

    function fulfillListing(uint256 listingId) internal {
        (,,,, uint256 price,,) = schmackoSwap.listings(listingId);

        //console.log("amt %s", amt);
        vm.startBroadcast(bob);
        schmackoSwap.changeBuyerAllowance(listingId, alice, true);
        vm.stopBroadcast();

        vm.startBroadcast(alice);
        erc20.approve(address(schmackoSwap), price);
        schmackoSwap.fulfill(listingId);
        vm.stopBroadcast();
    }

    function run() public {
        prepareAddresses();
        //the listing id depends on the current block number
        //it can't be relied on when executed inside the the same step since block.number changes after succinct transaction have been written
        //by moving this to another file you can simply provide a deterministic id here
        //it will change when you change anything on the Fixture script
        //note that the listing id that Fixture.s.sol yields is `16185769725485246688025311063236252188876072066352957050030366145926139000485` instead!
        //this here is the id that's written :D . I found it by temporarily storing it in the Swap contract and reading it again.
        uint256 listingId = 87888238617997826246110403553206171583436135582654702175720284244287514795609;
        fulfillListing(listingId);
    }
}

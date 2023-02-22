// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Fractionalizer } from "../src/Fractionalizer.sol";
import { IERC1155Supply } from "../src/IERC1155Supply.sol";

contract FractionalizerTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    bytes32 agreementHash = keccak256(bytes("the binary content of the fraction holder agreeemnt"));

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    IERC1155Supply internal ipnft;
    Fractionalizer internal fractionalizer;

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        IPNFT _ipnft = IPNFT(address(proxy));
        _ipnft.initialize();
        ipnft = IERC1155Supply(ipnft);

        Mintpass mintpass = new Mintpass(address(_ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        _ipnft.setAuthorizer(address(mintpass));
        mintpass.batchMint(originalOwner, 1);

        fractionalizer = new Fractionalizer();
        fractionalizer.initialize();
        fractionalizer.setFeeReceiver(protocolOwner);

        vm.stopPrank();

        vm.startPrank(originalOwner);
        uint256 reservationId = _ipnft.reserve();
        _ipnft.mintReservation(originalOwner, reservationId, 1, ipfsUri);
        vm.stopPrank();
    }

    function testLockAndIssueFractions() public {
        uint256 fractionAmt = 100_000;

        fractionalizer.fractionalizeUniqueERC1155(ipnft, 1, agreementHash, 100_000);
    }
}

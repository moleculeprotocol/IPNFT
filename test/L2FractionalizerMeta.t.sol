// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { MockCrossDomainMessenger } from "./helpers/MockCrossDomainMessenger.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { UnverifiedForwarder, ForwardRequest } from "./helpers/UnverifiedForwarder.sol";

import { Fractionalizer } from "../src/Fractionalizer.sol";
import { MyToken } from "../src/MyToken.sol";

contract L2FractionalizerTest is Test {
    string ipfsUri = "ipfs://bafkreiankqd3jvpzso6khstnaoxovtyezyatxdy7t2qzjoolqhltmasqki";
    bytes32 agreementHash = keccak256(bytes("the binary content of the fraction holder agreeemnt"));

    address PREDEPLOYED_XDOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    address deployer = makeAddr("chucknorris");
    address protocolOwner = makeAddr("protocolOwner");
    address originalOwner = makeAddr("daoMultisig");
    address ipnftBuyer = makeAddr("ipnftbuyer");
    address ipnftContract = makeAddr("ipnftv21");
    address FakeL1DispatcherContract = makeAddr("L1Dispatcher");
    address Relayer = makeAddr("OpenGSN or Defender");

    //Alice, Bob and Charlie are fraction holders
    address alice = makeAddr("alice");
    uint256 alicePk;

    address bob = makeAddr("bob");

    Fractionalizer internal fractionalizer;
    IERC20 internal erc20;
    MockCrossDomainMessenger internal xDomainMessenger;

    UnverifiedForwarder internal forwarder;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");

        vm.startPrank(deployer);

        MyToken myToken = new MyToken();
        myToken.mint(ipnftBuyer, 1_000_000 ether);
        erc20 = IERC20(address(myToken));

        xDomainMessenger = new MockCrossDomainMessenger();
        vm.etch(PREDEPLOYED_XDOMAIN_MESSENGER, address(xDomainMessenger).code);
        xDomainMessenger = MockCrossDomainMessenger(PREDEPLOYED_XDOMAIN_MESSENGER);
        forwarder = new UnverifiedForwarder();

        fractionalizer = Fractionalizer(
            address(
                new ERC1967Proxy(
                    address(
                        new Fractionalizer(address(forwarder))
                    ), ""
                )
            )
        );
        fractionalizer.initialize();
        fractionalizer.setFractionalizerDispatcherL1(FakeL1DispatcherContract);
        //fractionalizer.setFeeReceiver(protocolOwner);

        vm.stopPrank();
    }

    function helpInitializeFractions() internal returns (uint256 fractionId) {
        fractionId = uint256(keccak256(abi.encodePacked(originalOwner, ipnftContract, uint256(1))));

        xDomainMessenger.setSender(FakeL1DispatcherContract);
        bytes memory message =
            abi.encodeCall(Fractionalizer.fractionalizeUniqueERC1155, (fractionId, ipnftContract, uint256(1), originalOwner, agreementHash, 100_000));

        xDomainMessenger.sendMessage(address(fractionalizer), message, 1_900_000);
    }

    function testCheckSupportsMetaTransactions() public {
        uint256 fractionId = helpInitializeFractions();

        //check that usual transactions still work
        vm.startPrank(originalOwner);
        fractionalizer.safeTransferFrom(originalOwner, alice, fractionId, 25_000, "");
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(alice, fractionId), 25_000);
        assertEq(fractionalizer.balanceOf(bob, fractionId), 0);
        ForwardRequest memory req = ForwardRequest({
            from: originalOwner,
            to: address(fractionalizer),
            value: 0,
            gas: 120_000,
            nonce: forwarder.getNonce(originalOwner),
            data: abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", originalOwner, bob, fractionId, 25_000, "")
        });

        vm.startPrank(Relayer);
        forwarder.unsafeExecute(req);
        vm.stopPrank();

        assertEq(fractionalizer.balanceOf(bob, fractionId), 25_000);
    }
}

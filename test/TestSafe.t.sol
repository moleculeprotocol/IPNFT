// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { GnosisSafeL2 } from "safe-global/safe-contracts/GnosisSafeL2.sol";
import { GnosisSafeProxyFactory } from "safe-global/safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import { Enum } from "safe-global/safe-contracts/common/Enum.sol";

contract GnosisSafeSetup is Test {
    address deployer = makeAddr("chucknorris");
    address bob = makeAddr("bob");
    address alice;
    uint256 alicePk;

    GnosisSafeL2 wallet;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");

        vm.startPrank(deployer);
        GnosisSafeL2 singleton = new GnosisSafeL2();
        GnosisSafeProxyFactory fac = new GnosisSafeProxyFactory();
        wallet = GnosisSafeL2(payable(fac.createProxyWithNonce(address(singleton), "", uint256(1680130687))));

        address[] memory owners = new address[](1);
        owners[0] = alice;

        wallet.setup(owners, 1, address(0x0), "", address(0x0), address(0x0), 0, payable(address(0x0)));
        vm.stopPrank();
    }

    function testGeneralSetup() public {
        assertTrue(wallet.isOwner(alice));
    }

    function testSafeAcceptsMoney() public {
        vm.deal(bob, 10 ether);
        vm.startPrank(bob);
        (bool sent,) = payable(address(wallet)).call{ value: 5 ether }("");
        assertTrue(sent);
        vm.stopPrank();

        assertEq(address(wallet).balance, 5 ether);
    }

    function testOwnersCanInteractWithSafe() public {
        vm.deal(address(wallet), 10 ether);

        bytes32 encodedTxDataHash =
            wallet.getTransactionHash(bob, 1 ether, "", Enum.Operation.Call, 50_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), 0);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, encodedTxDataHash);
        bytes memory xsignatures = abi.encodePacked(r, s, v);

        vm.startPrank(alice);
        wallet.execTransaction(bob, 1 ether, "", Enum.Operation.Call, 50_000, 1 gwei, 20 gwei, address(0x0), payable(0x0), xsignatures);
        vm.stopPrank();

        assertEq(bob.balance, 1 ether);
        assertEq(address(wallet).balance, 9 ether);
    }
}

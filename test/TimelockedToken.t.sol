// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20MetadataUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { TimelockedToken, NotSupported, StillLocked, DuplicateSchedule } from "../src/TimelockedToken.sol";

contract TimelockedTokenTest is Test {
    address bene = makeAddr("beneficiary");
    address locker = makeAddr("locker");
    address anyone = makeAddr("anyone");

    FakeERC20 internal baseToken;
    TimelockedToken internal lockedToken;

    function setUp() public {
        baseToken = new FakeERC20("Base Token","BT");
        lockedToken = new TimelockedToken();
        lockedToken.initialize(IERC20MetadataUpgradeable(address(baseToken)));

        baseToken.mint(locker, 100_000 ether);
        vm.startPrank(locker);
        baseToken.approve(address(lockedToken), 100_000 ether);
        vm.stopPrank();
    }

    function testCanLock() public {
        vm.startPrank(locker);
        lockedToken.lock(bene, 50_000 ether, uint64(block.timestamp + 30 minutes));
        vm.stopPrank();

        assertEq(lockedToken.balanceOf(locker), 0);
        assertEq(lockedToken.balanceOf(bene), 50_000 ether);
        assertEq(lockedToken.totalSupply(), 50_000 ether);
    }

    function testCannotTransferOrApprove() public {
        vm.startPrank(locker);
        lockedToken.lock(bene, 50_000 ether, uint64(block.timestamp + 30 minutes));
        vm.stopPrank();

        vm.startPrank(bene);
        vm.expectRevert(NotSupported.selector);
        lockedToken.transfer(anyone, 10_000 ether);

        vm.expectRevert(NotSupported.selector);
        lockedToken.approve(anyone, 10_000 ether);
        vm.stopPrank();
    }

    function testCanWithdrawAfterLockingPeriod() public {
        vm.startPrank(locker);
        bytes32 scheduleId = lockedToken.lock(bene, 50_000 ether, uint64(block.timestamp + 30 minutes));
        vm.stopPrank();

        vm.startPrank(bene);
        vm.expectRevert(StillLocked.selector);
        lockedToken.release(scheduleId);
        vm.stopPrank();

        vm.warp(uint64(block.timestamp + 31 minutes));

        vm.startPrank(anyone);
        lockedToken.release(scheduleId);
        vm.stopPrank();

        assertEq(lockedToken.balanceOf(bene), 0);
        assertEq(baseToken.balanceOf(bene), 50_000 ether);
        assertEq(lockedToken.totalSupply(), 0);
        assertEq(lockedToken.balanceOf(bene), 0);
    }

    function testCanWithdrawSeveralSchedules() public {
        vm.startPrank(locker);
        bytes32 schedule1 = lockedToken.lock(bene, 20_000 ether, uint64(block.timestamp + 30 minutes));
        bytes32 schedule2 = lockedToken.lock(bene, 20_000 ether, uint64(block.timestamp + 60 minutes));
        bytes32 schedule3 = lockedToken.lock(bene, 20_000 ether, uint64(block.timestamp + 90 minutes));
        vm.stopPrank();

        vm.warp(block.timestamp + 62 minutes);
        vm.startPrank(anyone);
        bytes32[] memory unlockIds = new bytes32[](3);
        unlockIds[0] = schedule1;
        unlockIds[1] = schedule2;
        unlockIds[2] = schedule3;
        vm.expectRevert(StillLocked.selector);
        lockedToken.releaseMany(unlockIds);

        unlockIds = new bytes32[](2);
        unlockIds[0] = schedule1;
        unlockIds[1] = schedule2;
        lockedToken.releaseMany(unlockIds);
        vm.stopPrank();

        assertEq(lockedToken.balanceOf(bene), 20_000 ether);
        assertEq(lockedToken.totalSupply(), 20_000 ether);
    }

    function testThatCannotCreateTheSameSchedule() public {
        uint64 nowPlusHalfAnHour = uint64(block.timestamp + 30 minutes);
        vm.startPrank(locker);
        lockedToken.lock(bene, 50_000 ether, nowPlusHalfAnHour);
        vm.expectRevert(DuplicateSchedule.selector);
        lockedToken.lock(bene, 50_000 ether, nowPlusHalfAnHour);
        vm.stopPrank();
    }
}

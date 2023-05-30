// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20MetadataUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

struct Schedule {
    uint64 until;
    address beneficiary;
    uint256 amount;
}

error NotSupported();
error StillLocked();
error DuplicateSchedule();

contract TimelockedToken is IERC20MetadataUpgradeable, Initializable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    IERC20MetadataUpgradeable underlyingToken;
    uint256 public totalSupply;
    mapping(address => uint256) balances;
    mapping(bytes32 => Schedule) public schedules;

    function initialize(IERC20MetadataUpgradeable underlyingToken_) external initializer {
        underlyingToken = underlyingToken_;
    }

    /**
     * @inheritdoc IERC20MetadataUpgradeable
     */
    function name() external view returns (string memory) {
        return string.concat("Locked ", underlyingToken.name());
    }

    /**
     * @inheritdoc IERC20MetadataUpgradeable
     */
    function symbol() external view returns (string memory) {
        return string.concat("l", underlyingToken.symbol());
    }

    /**
     * @inheritdoc IERC20MetadataUpgradeable
     */
    function decimals() external view returns (uint8) {
        return underlyingToken.decimals();
    }

    function transfer(address, uint256) external pure returns (bool) {
        revert NotSupported();
    }

    function approve(address, uint256) external pure returns (bool) {
        revert NotSupported();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert NotSupported();
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function lock(address beneficiary, uint256 amount, uint64 untilTimestamp) external returns (bytes32 scheduleId) {
        if (untilTimestamp < block.timestamp + 15 minutes) {
            revert("too short notice");
        }

        scheduleId = keccak256(abi.encodePacked(msg.sender, beneficiary, amount, untilTimestamp));
        if (schedules[scheduleId].beneficiary != address(0)) {
            revert DuplicateSchedule();
        }
        schedules[scheduleId] = Schedule(untilTimestamp, beneficiary, amount);
        balances[beneficiary] += amount;
        totalSupply += amount;
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function release(bytes32 scheduleId) public {
        Schedule memory schedule = schedules[scheduleId];
        if (schedule.until > block.timestamp) {
            revert StillLocked();
        }
        totalSupply -= schedule.amount;
        balances[schedule.beneficiary] -= schedule.amount;
        delete schedules[scheduleId];
        underlyingToken.safeTransfer(schedule.beneficiary, schedule.amount);
    }

    function releaseMany(bytes32[] calldata scheduleIds) external {
        for (uint256 i = 0; i < scheduleIds.length; i++) {
            release(scheduleIds[i]);
        }
    }
}

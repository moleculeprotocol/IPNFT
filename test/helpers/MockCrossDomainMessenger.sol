// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";

contract MockCrossDomainMessenger is ICrossDomainMessenger {
    address internal sender;

    function setSender(address _sender) public {
        sender = _sender;
    }

    function xDomainMessageSender() external view returns (address) {
        return sender;
    }

    function sendMessage(address _target, bytes calldata _message, uint32 _gasLimit) external {
        emit ICrossDomainMessenger.SentMessage(_target, msg.sender, _message, 42, _gasLimit);
    }
}

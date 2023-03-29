// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";

contract MockCrossDomainMessenger is ICrossDomainMessenger {
    address internal sender;
    uint256 _nonce = 0;

    function setSender(address _sender) public {
        sender = _sender;
    }

    function xDomainMessageSender() external view returns (address) {
        return sender;
    }

    function sendMessage(address _target, bytes calldata _message, uint32 _gasLimit) external {
        _nonce = _nonce + 1;
        (bool success, bytes memory data) = _target.call{gas: _gasLimit}(_message);
        // console.logBool(success);
        // console.logBytes(data);
        if (!success) {
            revert(string(abi.encodePacked("relay failed: ", _getRevertMsg(data))));
        }
        emit ICrossDomainMessenger.SentMessage(_target, msg.sender, _message, _nonce, _gasLimit);
    }

    /// @dev https://ethereum.stackexchange.com/questions/83528/how-can-i-get-the-revert-reason-of-a-call-in-solidity-so-that-i-can-use-it-in-th
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}

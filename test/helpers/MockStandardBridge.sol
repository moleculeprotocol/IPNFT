// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";

/* solhint-disable */
contract MockStandardBridge is IL1ERC20Bridge {
    //https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/contracts/libraries/constants/Lib_PredeployAddresses.sol
    function l2TokenBridge() external returns (address) {
        return 0x4200000000000000000000000000000000000010;
    }

    function depositERC20(address _l1Token, address _l2Token, uint256 _amount, uint32 _l2Gas, bytes calldata _data) external {
        _l1Token;
        _l2Token;
        _amount;
        _l2Gas;
        _data;
        console.log("depositERC20");
    }

    function depositERC20To(address _l1Token, address _l2Token, address _to, uint256 _amount, uint32 _l2Gas, bytes calldata _data) external {
        _l1Token;
        _l2Token;
        _to;
        _amount;
        _l2Gas;
        _data;
        console.log("depositERC20To");
    }

    function finalizeERC20Withdrawal(address _l1Token, address _l2Token, address _from, address _to, uint256 _amount, bytes calldata _data)
        external
    {
        _l1Token;
        _l2Token;
        _from;
        _to;
        _amount;
        _data;
        console.log("finalizeERC20Withdrawal");
    }
}
/* solhint-enable */

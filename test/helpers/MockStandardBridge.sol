// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { ICrossDomainMessenger } from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";
import { IL1ERC20Bridge } from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* solhint-disable */
/**
 * a greedy testing bridge. It transfers all erc20 to itself. yumyum.
 * @title
 * @author
 * @notice
 */
contract MockStandardBridge is IL1ERC20Bridge {
    //https://github.com/ethereum-optimism/optimism/blob/develop/packages/contracts/contracts/libraries/constants/Lib_PredeployAddresses.sol
    function l2TokenBridge() external returns (address) {
        return 0x4200000000000000000000000000000000000010;
    }

    function depositERC20(address _l1Token, address _l2Token, uint256 _amount, uint32 _l2Gas, bytes calldata _data) external {
        _l2Token;
        _l2Gas;
        _data;
        console.log("Mock Bridge depositERC20 (%s)", _amount);
        IERC20(_l1Token).transferFrom(msg.sender, address(this), _amount);
    }

    function depositERC20To(address _l1Token, address _l2Token, address _to, uint256 _amount, uint32 _l2Gas, bytes calldata _data) external {
        _l2Token;
        _to;
        _l2Gas;
        _data;
        console.log("Mock Bridge depositERC20To (%s)", _amount);
        IERC20(_l1Token).transferFrom(msg.sender, address(this), _amount);
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

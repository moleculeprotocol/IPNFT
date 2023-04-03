// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    bytes data;
}

/**
 * @notice DONT USE THIS *EVER* IN PUBLIC. ONLY HERE FOR TESTING
 * @notice see OZ:MinimalForwarder
 */

contract UnverifiedForwarder {
    mapping(address => uint256) private _nonces;

    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }

    function unsafeExecute(ForwardRequest calldata req) public payable returns (bool, bytes memory) {
        //require(verify(req, signature), "MinimalForwarder: signature does not match request");
        _nonces[req.from] = req.nonce + 1;

        (bool success, bytes memory returndata) = req.to.call{ gas: req.gas, value: req.value }(abi.encodePacked(req.data, req.from));

        // Validate that the relayer has sent enough gas for the call.
        // See https://ronan.eth.limo/blog/ethereum-gas-dangers/
        if (gasleft() <= req.gas / 63) {
            // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
            // neither revert or assert consume all gas since Solidity 0.8.0
            // https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require
            /// @solidity memory-safe-assembly
            assembly {
                invalid()
            }
        }

        return (success, returndata);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title Collective Access Guard
/// @author molecule.to
/// @notice Tries to check whether an address either owns a single 1155 asset or
contract CollectiveAccessGuard {
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    /// @dev Returns the chain id used by this contract.
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }

    function isLikelyGSafe(address _addr) internal returns (bool) {
        if (!isContract(_addr)) {
            return false;
        }
        (bool success, bytes memory separatorResult) = _addr.call{gas: 5000}(abi.encodeWithSignature("domainSeparator()"));
        if (!success) return false;

        bytes32 _theirDomainSeparator = abi.decode(separatorResult, (bytes32));
        bytes32 _ourDomainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), _addr));
        return (_theirDomainSeparator == _ourDomainSeparator);
    }

    function checkIfCallerIsMemberOfSafe(address safe, address caller) internal returns (bool) {
        (bool success, bytes memory ownerResult) = safe.call{gas: 10000}(abi.encodeWithSignature("isOwner(address)", caller));
        if (!success) return false;
        bool isOwner = abi.decode(ownerResult, (bool));
        return isOwner;
    }

    /**
     * @param erc1155 can be an ERC1155 or a contract that exposes an `ownerOf` method, e.g. an extended ERC1155 or a default ERC721 contract
     * @param tokenId token id
     * @param member the address to check ownership for
     */
    function canAccessContent(IERC1155 erc1155, uint256 tokenId, address member) public returns (bool) {
        try erc1155.balanceOf(member, tokenId) returns (uint256 balance) {
            if (balance > 0) return true;
        } catch (bytes memory) { }

        address ownableContract = address(erc1155);
        (bool success, bytes memory ownerResult_) = ownableContract.call{gas: 5000}(abi.encodeWithSignature("ownerOf(uint256)", tokenId));
        if (!success) {
            return false;
        }

        address owner = abi.decode(ownerResult_, (address));
        if (erc1155.balanceOf(owner, tokenId) == 0) {
            return false;
        }

        if (!isLikelyGSafe(owner)) {
            return false;
        }

        if (!checkIfCallerIsMemberOfSafe(owner, member)) {
            return false;
        }

        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IControlIPTs } from "./IControlIPTs.sol";
import { IIPToken, Metadata } from "./IIPToken.sol";
import { MustControlIpnft, Tokenizer } from "./Tokenizer.sol";
import { IPTokenUtils } from "./libraries/IPTokenUtils.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

error TokenCapped();

/**
 * @title IPToken 1.3
 * @author molecule.xyz
 * @notice this is a template contract that's cloned by the Tokenizer
 * @notice the owner of this contract is always the Tokenizer contract which enforces IPNFT holdership rules.
 *         The owner can increase the token supply as long as it's not explicitly capped.
 * @dev formerly known as "molecules"
 */
contract IPToken is IIPToken, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    event Capped(uint256 atSupply);

    /// @notice the amount of tokens that ever have been issued (not necessarily == supply)
    uint256 public totalIssued;

    /// @notice when true, no one can ever mint tokens again.
    bool public capped;

    Metadata internal _metadata;

    function initialize(uint256 ipnftId, string calldata name_, string calldata symbol_, address originalOwner, string memory agreementCid)
        external
        initializer
    {
        __Ownable_init();
        __ERC20_init(name_, symbol_);
        _metadata = Metadata({ ipnftId: ipnftId, originalOwner: originalOwner, agreementCid: agreementCid });
    }

    constructor() {
        _disableInitializers();
    }

    modifier onlyTokenizerOrIPNFTController() {
        if (_msgSender() != owner() && _msgSender() != IControlIPTs(owner()).controllerOf(_metadata.ipnftId)) {
            revert MustControlIpnft();
        }
        _;
    }

    function metadata() external view override returns (Metadata memory) {
        return _metadata;
    }

    // Override ERC20 functions to resolve diamond inheritance
    function totalSupply() public view override returns (uint256) {
        return ERC20Upgradeable.totalSupply();
    }

    function balanceOf(address account) public view override returns (uint256) {
        return ERC20Upgradeable.balanceOf(account);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        return ERC20Upgradeable.transfer(to, amount);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return ERC20Upgradeable.allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        return ERC20Upgradeable.approve(spender, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return ERC20Upgradeable.transferFrom(from, to, amount);
    }

    function name() public view override returns (string memory) {
        return ERC20Upgradeable.name();
    }

    function symbol() public view override returns (string memory) {
        return ERC20Upgradeable.symbol();
    }

    function decimals() public view override returns (uint8) {
        return ERC20Upgradeable.decimals();
    }

    /**
     * @notice the supply of IP Tokens is controlled by the tokenizer contract.
     * @param receiver address
     * @param amount uint256
     */
    function issue(address receiver, uint256 amount) external override onlyTokenizerOrIPNFTController {
        if (capped) {
            revert TokenCapped();
        }
        totalIssued += amount;
        _mint(receiver, amount);
    }

    /**
     * @notice mark this token as capped. After calling this, no new tokens can be `issue`d
     */
    function cap() external override onlyTokenizerOrIPNFTController {
        capped = true;
        emit Capped(totalIssued);
    }

    /**
     * @notice contract metadata, compatible to ERC1155
     * @return string base64 encoded data url
     */
    function uri() external view override returns (string memory) {
        return IPTokenUtils.generateURI(_metadata, address(this), totalIssued);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Tokenizer, MustControlIpnft } from "../../Tokenizer.sol";
import { IControlIPTs } from "../../IControlIPTs.sol";

struct Metadata {
    uint256 ipnftId;
    address originalOwner;
    string agreementCid;
}

error TokenCapped();

/**
 * @title IPToken 1.3
 * @author molecule.xyz
 * @notice this is a template contract that's cloned by the Tokenizer
 * @notice the owner of this contract is always the Tokenizer contract which enforces IPNFT holdership rules.
 *         The owner can increase the token supply as long as it's not explicitly capped.
 * @dev formerly known as "molecules"
 */
contract IPToken13 is ERC20BurnableUpgradeable, OwnableUpgradeable {
    event Capped(uint256 atSupply);

    /// @notice the amount of tokens that ever have been issued (not necessarily == supply)
    uint256 public totalIssued;

    /// @notice when true, no one can ever mint tokens again.
    bool public capped;

    Metadata internal _metadata;

    function initialize(uint256 ipnftId, string calldata name, string calldata symbol, address originalOwner, string memory agreementCid)
        external
        initializer
    {
        __Ownable_init();
        __ERC20_init(name, symbol);
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

    function metadata() external view returns (Metadata memory) {
        return _metadata;
    }

    /**
     * @notice the supply of IP Tokens is controlled by the tokenizer contract.
     * @param receiver address
     * @param amount uint256
     */
    function issue(address receiver, uint256 amount) external onlyTokenizerOrIPNFTController {
        if (capped) {
            revert TokenCapped();
        }
        totalIssued += amount;
        _mint(receiver, amount);
    }

    /**
     * @notice mark this token as capped. After calling this, no new tokens can be `issue`d
     */
    function cap() external onlyTokenizerOrIPNFTController {
        capped = true;
        emit Capped(totalIssued);
    }

    /**
     * @notice contract metadata, compatible to ERC1155
     * @return string base64 encoded data url
     */
    function uri() external view returns (string memory) {
        string memory tokenId = Strings.toString(_metadata.ipnftId);

        string memory props = string.concat(
            '"properties": {',
            '"ipnft_id": ',
            tokenId,
            ',"agreement_content": "ipfs://',
            _metadata.agreementCid,
            '","original_owner": "',
            Strings.toHexString(_metadata.originalOwner),
            '","erc20_contract": "',
            Strings.toHexString(address(this)),
            '","supply": "',
            Strings.toString(totalIssued),
            '"}'
        );

        return string.concat(
            "data:application/json;base64,",
            Base64.encode(
                bytes(
                    string.concat(
                        '{"name": "IP Tokens of IPNFT #',
                        tokenId,
                        '","description": "IP Tokens, derived from IP-NFTs, are ERC-20 tokens governing IP pools.","decimals": 18,"external_url": "https://molecule.to","image": "",',
                        props,
                        "}"
                    )
                )
            )
        );
    }
}

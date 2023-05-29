// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { FractionalizedToken, Metadata as FractionalizedTokenMetadata } from "./FractionalizedToken.sol";
import { IPNFT } from "./IPNFT.sol";

error ToZeroAddress();

error BadSupply();
error MustOwnIpnft();
error NoSymbol();
error AlreadyFractionalized();

/// @title Fractionalizer
/// @author molecule.to
/// @notice fractionalizes an IPNFT to an ERC20 token and controls its supply.
///         Allows fraction holders to withdraw sales shares when the IPNFT is sold
contract Fractionalizer is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event FractionsCreated(
        uint256 indexed fractionId,
        uint256 indexed ipnftId,
        address indexed tokenContract,
        address emitter,
        uint256 amount,
        string agreementCid,
        string name,
        string symbol
    );

    IPNFT internal ipnft;

    address internal feeReceiver;
    uint256 internal fractionalizationPercentage;

    mapping(uint256 => FractionalizedToken) public fractionalized;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address immutable tokenImplementation;

    function initialize(IPNFT _ipnft) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        ipnft = _ipnft;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        tokenImplementation = address(new FractionalizedToken());
        _disableInitializers();
    }

    /**
     * @notice we're not taking any fees. If we once decided to do so, this can be used to update the fee receiver
     * @param _feeReceiver the address that will receive fraction fees
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }

    /**
     * @notice unused in this version
     * @param fractionalizationPercentage_  uint256 the fee percentage `feeReceiver` takes on a new fractionalization
     */
    function setReceiverPercentage(uint256 fractionalizationPercentage_) external onlyOwner {
        fractionalizationPercentage = fractionalizationPercentage_;
    }

    /**
     * @notice initializes fractions on ipnft#id for the current asset holder.
     *         Fractional tokens are identified by the original token holder and the token id
     * @param ipnftId the token id on the underlying nft collection
     * @param fractionsAmount the initially issued supply of fraction tokens
     * @param agreementCid a content hash that contains legal terms for fraction owners
     */
    function fractionalizeIpnft(uint256 ipnftId, uint256 fractionsAmount, string calldata agreementCid)
        external
        nonReentrant
        returns (FractionalizedToken token)
    {
        if (ipnft.totalSupply(ipnftId) != 1) {
            revert BadSupply();
        }
        if (ipnft.balanceOf(_msgSender(), ipnftId) != 1) {
            revert MustOwnIpnft();
        }
        string memory ipnftSymbol = ipnft.symbol(ipnftId);
        if (bytes(ipnftSymbol).length == 0) {
            revert NoSymbol();
        }

        // https://github.com/OpenZeppelin/workshops/tree/master/02-contracts-clone
        FractionalizedToken fractionalizedToken = FractionalizedToken(Clones.clone(tokenImplementation));
        string memory name = string(abi.encodePacked("Fractions of IPNFT #", Strings.toString(ipnftId)));
        fractionalizedToken.initialize(
            name, string(abi.encodePacked(ipnftSymbol, "-MOL")), FractionalizedTokenMetadata(ipnftId, _msgSender(), agreementCid)
        );
        uint256 fractionHash = fractionalizedToken.hash();
        // ensure we can only call this once per sales cycle
        if (address(fractionalized[fractionHash]) != address(0)) {
            revert AlreadyFractionalized();
        }

        fractionalized[fractionHash] = fractionalizedToken;

        emit FractionsCreated(fractionHash, ipnftId, address(fractionalizedToken), _msgSender(), fractionsAmount, agreementCid, name, ipnftSymbol);

        //if we want to take a protocol fee, this might be a good point of doing so.
        fractionalizedToken.issue(_msgSender(), fractionsAmount);

        return fractionalizedToken;
    }

    /// @notice upgrade authorization logic
    function _authorizeUpgrade(address /*newImplementation*/ )
        internal
        override
        onlyOwner // solhint-disable-next-line no-empty-blocks
    {
        //empty block
    }

    /**
     * @notice contract metadata, compatible to ERC1155
     * @param fractionHash uint256
     */
    function uri(uint256 fractionHash) external view returns (string memory) {
        FractionalizedToken tokenContract = fractionalized[fractionHash];
        FractionalizedTokenMetadata memory metadata = tokenContract.metadata();
        string memory tokenId = Strings.toString(metadata.ipnftId);

        string memory props = string(
            abi.encodePacked(
                '"properties": {',
                '"ipnft_id": ',
                tokenId,
                ',"agreement_content": "ipfs://',
                metadata.agreementCid,
                '","original_owner": "',
                Strings.toHexString(metadata.originalOwner),
                '","erc20_contract": "',
                Strings.toHexString(address(tokenContract)),
                '","supply": "',
                Strings.toString(tokenContract.totalIssued()),
                '"}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name": "Fractions of IPNFT #',
                        tokenId,
                        '","description": "this token represents fractions of the underlying asset","decimals": 18,"external_url": "https://molecule.to","image": "",',
                        props,
                        "}"
                    )
                )
            )
        );
    }
}

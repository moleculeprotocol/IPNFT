// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import { IPNFT3525V2 } from "./IPNFT3525V2.sol";
import { IPNFT } from "./Structs.sol";

interface IIPNFTMetadata {
    function generateContractURI() external view returns (string memory);

    function generateSlotURI(IPNFT memory slot) external pure returns (string memory);

    function generateTokenURI(IPNFT memory ipnft, uint256 tokenId, uint256 slotId, uint256 tokenBalance)
        external
        pure
        returns (string memory);
}

contract IPNFTMetadata is IIPNFTMetadata {
    using Strings for uint256;

    function generateSlotURI(IPNFT memory slot) external pure returns (string memory) {
        string memory properties = string(
            abi.encodePacked(
                '"properties": [',
                '{"name":"agreement_url","description":"agreement","display_type":"url",',
                '"value":"',
                slot.agreementUrl,
                '"},',
                '{"name":"project_details_url","description":"project","display_type":"url",',
                '"value":"',
                slot.projectDetailsUrl,
                '"}',
                "]"
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"',
                        slot.name,
                        '","description":"',
                        slot.description,
                        '","image":"',
                        slot.imageUrl,
                        '",',
                        properties,
                        "}"
                    )
                )
            )
        );
    }

    function generateTokenURI(IPNFT memory ipnft, uint256 tokenId, uint256 slotId, uint256 tokenBalance)
        external
        pure
        returns (string memory)
    {
        string memory properties = string(
            abi.encodePacked(
                '"properties": {',
                '"type":"IP-NFT",',
                '"external_url":"https://discover.molecule.to/ipnft/',
                tokenId.toString(),
                '","agreement_url":"',
                ipnft.agreementUrl,
                '","project_details_url":"',
                ipnft.projectDetailsUrl,
                '"}'
            )
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"',
                        ipnft.name,
                        '","description":"',
                        ipnft.description,
                        '","image":"',
                        ipnft.imageUrl,
                        '","balance":"',
                        tokenBalance.toString(),
                        '","slot":',
                        slotId.toString(),
                        ",",
                        properties,
                        "}"
                    )
                )
            )
        );
    }

    //todo: use better metadata / image
    function generateContractURI() external pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"IP-NFT"'
                        '","description":"IP-NFTs are a decentralized representation of intellectual property. They contain legal information and allow fractionalized licensing on chain.","image":"'
                        "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU" '","external_url":"https://molecule.to"}'
                    )
                )
            )
        );
    }
}

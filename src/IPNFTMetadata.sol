// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

interface IIPNFT3525 {
    struct IPNFT {
        uint256 totalUnits;
        uint16 version;
        bool exists;
        string name;
        string description;
        string imageUrl;
        string agreementUrl;
        string projectDetailsUrl;
        address minter;
    }
}

interface IIPNFTMetadata {
    // function generateContractURI() external view returns (string memory);

    // function generateSlotURI(uint256 slotId) external view returns (string memory);

    function generateTokenURI(uint256 slotId, IIPNFT3525.IPNFT memory slot) external pure returns (string memory);
}

contract IPNFTMetadata is IIPNFTMetadata {
    using Strings for uint256;

    function generateTokenURI(uint256 slotId, IIPNFT3525.IPNFT memory slot) external pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json,",
                abi.encodePacked(
                    '{"name":"',
                    slot.name,
                    '","description":"',
                    slot.description,
                    '","image":"',
                    slot.imageUrl,
                    '","balance":0,',
                    '"slot":',
                    slotId.toString(),
                    ',"properties": {',
                    '"type":"IP-NFT",',
                    '"external_url":"https://discover.molecule.to/ipnft/',
                    slotId.toString(),
                    '","agreement_url":"',
                    slot.agreementUrl,
                    '","project_details_url":"',
                    slot.projectDetailsUrl,
                    '"} }'
                )
            )
        );
    }
}

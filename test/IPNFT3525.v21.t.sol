// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IPNFT3525V21 } from "../src/IPNFT3525V21.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { UUPSProxy } from "../src/UUPSProxy.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { IPNFTMetadata } from "../src/IPNFTMetadata.sol";

contract IPNFT3525V21Test is IPNFTMintHelper {
    IPNFT3525V21 implementationV21;
    UUPSProxy proxy;
    IPNFT3525V21 ipnft;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        vm.startPrank(deployer);
        implementationV21 = new IPNFT3525V21();
        proxy = new UUPSProxy(address(implementationV21), "");
        ipnft = IPNFT3525V21(address(proxy));
        ipnft.initialize();

        ipnft.setMetadataGenerator(new IPNFTMetadata());

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setMintpassContract(address(mintpass));
        vm.stopPrank();
    }

    function testContractName() public {
        assertEq(ipnft.name(), "IP-NFT V2.1");
    }

    function testMinting() public {
        mintAToken(ipnft, alice);

        assertEq(ipnft.totalSupply(), 1);
        string memory tokenUri_ = ipnft.tokenURI(1);

        assertEq(
            tokenUri_,
            "data:application/json;base64,eyJuYW1lIjoiSVAtTkZUIFRlc3QiLCJkZXNjcmlwdGlvbiI6IlNvbWUgRGVzY3JpcHRpb24iLCJpbWFnZSI6ImFyOi8vN0RlNmRSTERhTWhNZUM2VXRtOWJCOVBSYmN2S2RpLXJ3X3NETThwSlNNVSIsImJhbGFuY2UiOiIxMDAwMDAwIiwic2xvdCI6MSwicHJvcGVydGllcyI6IHsidHlwZSI6IklQLU5GVCIsImV4dGVybmFsX3VybCI6Imh0dHBzOi8vZGlzY292ZXIubW9sZWN1bGUudG8vaXBuZnQvMSIsImFncmVlbWVudF91cmwiOiJpcGZzOi8vYmFmeWJlaWV3c2Y1aWxkcGpiY29rMjV0cms2emJnYWZldTRmdXhvaDVpd2ptdmNtZmk2MmRtb2hjd20vYWdyZWVtZW50Lmpzb24iLCJwcm9qZWN0X2RldGFpbHNfdXJsIjoiaXBmczovL2JhZnliZWlmaHdqN2d4N2ZqYjJkcjNxbzRhbTZrb2cycHNlZWdybmZyZzUzcG81NXpyeHpzYzZqNDVlL3Byb2plY3REZXRhaWxzLmpzb24ifX0="
        );
        //'data:application/json,{"name":"IP-NFT Test","description":"Some Description","image":"ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU","balance":"1000000","slot":1,"properties": {"type":"IP-NFT","external_url":"https://discover.molecule.to/ipnft/1","agreement_url":"ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json","project_details_url":"ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json"}}'

        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.tokenOfOwnerByIndex(alice, 0), 1);
    }

    // // todo: this is currently unsupported since I removed the initial fraction arg
    // // function testCanMintWithMoreThanOneFraction() public {
    // //     uint64[] memory fractions = new uint64[](2);
    // //     fractions[0] = 50;
    // //     fractions[1] = 50;

    // //     bytes memory ipnftArgs = abi.encode("", "", "", fractions);

    // //     ipnft.mint(alice, ipnftArgs);

    // //     assertEq(ipnft.ownerOf(1), alice);
    // //     assertEq(ipnft.ownerOf(2), alice);

    // //     assertEq(ipnft.balanceOf(1), 50);
    // //     assertEq(ipnft.balanceOf(2), 50);

    // //     assertEq(ipnft.tokenSupplyInSlot(1), 2);
    // // }

    function testSplitandMerge() public {
        mintAToken(ipnft, alice);

        assertEq(ipnft.balanceOf(1), 1_000_000);
        assertEq(ipnft.balanceOf(alice), 1);
        assertEq(ipnft.tokenSupplyInSlot(1), 1);

        vm.startPrank(alice);
        uint256[] memory fractions = new uint256[](2);
        fractions[0] = 500_000;
        fractions[1] = 500_000;

        //this creates another NFT on the same slot:
        ipnft.split(1, fractions);
        assertEq(ipnft.balanceOf(1), 500_000);
        assertEq(ipnft.balanceOf(2), 500_000);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), alice);

        assertEq(ipnft.slotOf(1), 1);
        assertEq(ipnft.slotOf(2), 1);

        //note that this is 2 now!
        assertEq(ipnft.tokenSupplyInSlot(1), 2);
        assertEq(ipnft.balanceOf(alice), 2);

        //note the merge order matters: we're merging towards the last token id in the list.
        uint256[] memory tokenIdsToMerge = new uint256[](2);
        tokenIdsToMerge[0] = 2;
        tokenIdsToMerge[1] = 1;

        ipnft.merge(tokenIdsToMerge);

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.balanceOf(1), 1_000_000);

        //note that this is 1 again!
        assertEq(ipnft.tokenSupplyInSlot(1), 1);
        vm.stopPrank();
    }

    function testTransferValueToANewUser() public {
        mintAToken(ipnft, alice);
        vm.startPrank(alice);
        ipnft.transferFrom(1, bob, 500_000);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), alice);
        assertEq(ipnft.ownerOf(2), bob);
        assertEq(ipnft.balanceOf(1), 500_000);
        assertEq(ipnft.balanceOf(2), 500_000);

        assertEq(
            ipnft.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjoiSVAtTkZUIFRlc3QiLCJkZXNjcmlwdGlvbiI6IlNvbWUgRGVzY3JpcHRpb24iLCJpbWFnZSI6ImFyOi8vN0RlNmRSTERhTWhNZUM2VXRtOWJCOVBSYmN2S2RpLXJ3X3NETThwSlNNVSIsImJhbGFuY2UiOiI1MDAwMDAiLCJzbG90IjoxLCJwcm9wZXJ0aWVzIjogeyJ0eXBlIjoiSVAtTkZUIiwiZXh0ZXJuYWxfdXJsIjoiaHR0cHM6Ly9kaXNjb3Zlci5tb2xlY3VsZS50by9pcG5mdC8xIiwiYWdyZWVtZW50X3VybCI6ImlwZnM6Ly9iYWZ5YmVpZXdzZjVpbGRwamJjb2syNXRyazZ6YmdhZmV1NGZ1eG9oNWl3am12Y21maTYyZG1vaGN3bS9hZ3JlZW1lbnQuanNvbiIsInByb2plY3RfZGV0YWlsc191cmwiOiJpcGZzOi8vYmFmeWJlaWZod2o3Z3g3ZmpiMmRyM3FvNGFtNmtvZzJwc2VlZ3JuZnJnNTNwbzU1enJ4enNjNmo0NWUvcHJvamVjdERldGFpbHMuanNvbiJ9fQ=="
        );
        // 'data:application/json,{"name":"IP-NFT Test","description":"Some Description","image":"ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU","balance":"500000","slot":1,"properties": {"type":"IP-NFT","external_url":"https://discover.molecule.to/ipnft/1","agreement_url":"ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json","project_details_url":"ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json"}}'

        assertEq(
            ipnft.tokenURI(2),
            "data:application/json;base64,eyJuYW1lIjoiSVAtTkZUIFRlc3QiLCJkZXNjcmlwdGlvbiI6IlNvbWUgRGVzY3JpcHRpb24iLCJpbWFnZSI6ImFyOi8vN0RlNmRSTERhTWhNZUM2VXRtOWJCOVBSYmN2S2RpLXJ3X3NETThwSlNNVSIsImJhbGFuY2UiOiI1MDAwMDAiLCJzbG90IjoxLCJwcm9wZXJ0aWVzIjogeyJ0eXBlIjoiSVAtTkZUIiwiZXh0ZXJuYWxfdXJsIjoiaHR0cHM6Ly9kaXNjb3Zlci5tb2xlY3VsZS50by9pcG5mdC8yIiwiYWdyZWVtZW50X3VybCI6ImlwZnM6Ly9iYWZ5YmVpZXdzZjVpbGRwamJjb2syNXRyazZ6YmdhZmV1NGZ1eG9oNWl3am12Y21maTYyZG1vaGN3bS9hZ3JlZW1lbnQuanNvbiIsInByb2plY3RfZGV0YWlsc191cmwiOiJpcGZzOi8vYmFmeWJlaWZod2o3Z3g3ZmpiMmRyM3FvNGFtNmtvZzJwc2VlZ3JuZnJnNTNwbzU1enJ4enNjNmo0NWUvcHJvamVjdERldGFpbHMuanNvbiJ9fQ=="
        );
        // 'data:application/json,{"name":"IP-NFT Test","description":"Some Description","image":"ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU","balance":"500000","slot":1,"properties": {"type":"IP-NFT","external_url":"https://discover.molecule.to/ipnft/2","agreement_url":"ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm/agreement.json","project_details_url":"ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e/projectDetails.json"}}'

        //todo this fails because tokenSupplyInSlot isn't increased during transfers.
        //https://github.com/Network-Goods/hypercerts-protocol/issues/54
        //assertEq(ipnft.tokenSupplyInSlot(1), 2);
    }

    //todo: this is disabled since I removed the initial fraction arg.
    // function testSplittingValuelessTokens() public {
    //     uint64[] memory fractions = new uint64[](1);
    //     fractions[0] = 0;

    //     vm.startPrank(alice);
    //     ipnft.mint(alice, abi.encode("", "", "", fractions));
    //     assertEq(ipnft.balanceOf(alice), 1);
    //     assertEq(ipnft.balanceOf(1), 0);

    //     ipnft.transferFrom(1, bob, 0);
    //     assertEq(ipnft.ownerOf(2), bob);
    //     assertEq(ipnft.totalSupply(), 2);

    //     vm.stopPrank();
    //     vm.startPrank(bob);
    //     ipnft.safeTransferFrom(bob, alice, 2);
    //     vm.stopPrank();
    //     vm.startPrank(alice);
    //     uint256[] memory tokenIdsToMerge = new uint256[](2);
    //     tokenIdsToMerge[0] = 2;
    //     tokenIdsToMerge[1] = 1;
    //     ipnft.merge(tokenIdsToMerge);
    //     //todo total supply is still 2!
    //     assertEq(ipnft.totalSupply(), 1);

    //     assertEq(ipnft.balanceOf(alice), 1);
    //     assertEq(ipnft.balanceOf(1), 0);

    //     ipnft.burn(1);
    //     //todo total supply is still 2!
    //     assertEq(ipnft.totalSupply(), 0);
    //     vm.stopPrank();
    // }

    function testFailCantMergeTokensThatYouDontOwn() public {
        mintAToken(ipnft, alice);
        vm.startPrank(alice);
        ipnft.transferFrom(1, bob, 5);
        uint256[] memory tokenIdsToMerge = new uint256[](2);
        tokenIdsToMerge[0] = 2;
        tokenIdsToMerge[1] = 1;
        ipnft.merge(tokenIdsToMerge);
    }

    function testBurnMintedTokens() public {
        mintAToken(ipnft, alice);
        vm.startPrank(alice);
        ipnft.burn(1);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(alice), 0);
    }

    function testFailBurnOwnedTokens() public {
        mintAToken(ipnft, alice);
        vm.startPrank(alice);
        ipnft.transferFrom(1, bob, 500_000);
        vm.stopPrank();

        vm.startPrank(bob);
        assertEq(ipnft.ownerOf(2), bob);
        //todo only the minter (alice) can burn the token
        //see IPNFT3525V21::burn
        ipnft.burn(2);
        assertEq(ipnft.balanceOf(bob), 0);
        vm.stopPrank();
    }
}

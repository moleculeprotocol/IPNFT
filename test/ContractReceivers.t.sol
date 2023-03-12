// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import { Mintpass } from "../src/Mintpass.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { UUPSProxy } from "../src/UUPSProxy.sol";
import { console } from "forge-std/console.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract TestToken is ERC20("USD Coin", "USDC", 18) {
    function mintTo(address recipient, uint256 amount) public payable {
        _mint(recipient, amount);
    }
}

contract BoringContractWallet {
    address public owner;

    constructor() {
        owner = msg.sender;
    }
}

contract CleverContractWallet is BoringContractWallet, ERC165 {
    function startSelling(address schmackoswap, address ipnft, address paymentToken, uint256 tokenId, address allowedBuyer)
        public
        returns (uint256 listingId)
    {
        if (msg.sender != owner) revert("not owner");
        ipnft.call(abi.encodeWithSignature("setApprovalForAll(address,bool)", schmackoswap, true));
        (bool success, bytes memory listResult_) =
            schmackoswap.call(abi.encodeWithSignature("list(address,uint256,address,uint256)", ipnft, tokenId, paymentToken, 1 ether));
        listingId = abi.decode(listResult_, (uint256));

        (bool apprRes,) = schmackoswap.call(abi.encodeWithSignature("changeBuyerAllowance(uint256,address,bool)", listingId, allowedBuyer, true));
    }

    function buy(SchmackoSwap schmackoswap, address paymentToken, uint256 listingId) public returns (bool) {
        if (msg.sender != owner) revert("not owner");
        (,, address creator_,,, uint256 price_,,) = schmackoswap.listings(listingId);

        paymentToken.call(abi.encodeWithSignature("approve(address,uint256)", address(schmackoswap), price_));
        (bool success,) = address(schmackoswap).call(abi.encodeWithSignature("fulfill(uint256)", listingId));
        return success;
    }

    function release(address ipnft, uint256 tokenId) public {
        if (msg.sender != owner) revert("not owner");
        (bool success,) =
            ipnft.call(abi.encodeWithSignature("safeTransferFrom(address,address,uint256,uint256,bytes)", address(this), owner, tokenId, 1, ""));
        if (!success) revert("cant withdraw token");
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == this.onERC1155Received.selector || super.supportsInterface(interfaceId);
    }
}

contract ContractReceiverTest is IPNFTMintHelper {
    address owner = makeAddr("contractowner");
    address buyer = makeAddr("buyer");
    address otherUser = makeAddr("otherUser");

    SchmackoSwap internal schmackoSwap;
    TestToken internal testToken;

    event Listed(uint256 listingId, SchmackoSwap.Listing listing);
    event Unlisted(uint256 listingId, SchmackoSwap.Listing listing);
    event Purchased(uint256 listingId, address indexed buyer, SchmackoSwap.Listing listing);
    event AllowlistUpdated(uint256 listingId, address indexed buyer, bool _isAllowed);

    IPNFT internal ipnft;

    function setUp() public {
        vm.startPrank(deployer);
        IPNFT implementationV2 = new IPNFT();
        UUPSProxy proxy = new UUPSProxy(address(implementationV2), "");
        ipnft = IPNFT(address(proxy));
        ipnft.initialize();

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        schmackoSwap = new SchmackoSwap();

        testToken = new TestToken();
        testToken.mintTo(buyer, 1 ether);

        vm.stopPrank();
    }

    function testCanOnlyMintToERC1155Receiver() public {
        dealMintpass(owner);
        vm.startPrank(owner);

        uint256 reservationId = ipnft.reserve();
        BoringContractWallet boringWallet = new BoringContractWallet();
        vm.expectRevert(bytes("ERC1155: transfer to non-ERC1155Receiver implementer"));
        ipnft.mintReservation(address(boringWallet), reservationId, 1, arUri);
        CleverContractWallet wallet = new CleverContractWallet();
        ipnft.mintReservation(address(wallet), reservationId, 1, arUri);
        vm.stopPrank();

        assertEq(ipnft.balanceOf(address(wallet), 1), 1);
    }

    function testAbstractAccountsCanTradeIPNFTs() public {
        dealMintpass(owner);

        vm.startPrank(buyer);
        CleverContractWallet buyerWallet = new CleverContractWallet();
        testToken.transfer(address(buyerWallet), 1 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        CleverContractWallet wallet = new CleverContractWallet();
        uint256 reservationId = ipnft.reserve();
        ipnft.mintReservation(address(wallet), reservationId, 1, arUri);

        uint256 listingId = wallet.startSelling(address(schmackoSwap), address(ipnft), address(testToken), 1, address(buyerWallet));
        vm.stopPrank();

        (,, address creator_,,, uint256 price_,,) = schmackoSwap.listings(listingId);
        assertEq(ipnft.balanceOf(address(wallet), 1), 1);
        assertEq(creator_, address(wallet));
        assertEq(price_, 1 ether);

        vm.startPrank(buyer);
        bool buyRes = buyerWallet.buy(schmackoSwap, address(testToken), listingId);
        assertEq(buyRes, true);

        assertEq(ipnft.balanceOf(address(wallet), 1), 0);
        assertEq(ipnft.balanceOf(address(buyerWallet), 1), 1);

        buyerWallet.release(address(ipnft), 1);
        assertEq(ipnft.balanceOf(address(buyerWallet), 1), 0);
        assertEq(ipnft.balanceOf(buyer, 1), 1);
        vm.stopPrank();
    }
}

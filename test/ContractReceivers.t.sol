// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { IPNFT } from "../src/IPNFT.sol";
import { Mintpass } from "../src/Mintpass.sol";
import { SchmackoSwap } from "../src/SchmackoSwap.sol";
import { FakeERC20 } from "../src/helpers/FakeERC20.sol";
import { IPNFTMintHelper } from "./IPNFTMintHelper.sol";

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
        (, bytes memory listResult_) =
            schmackoswap.call(abi.encodeWithSignature("list(address,uint256,address,uint256)", ipnft, tokenId, paymentToken, 1 ether));
        listingId = abi.decode(listResult_, (uint256));

        schmackoswap.call(abi.encodeWithSignature("changeBuyerAllowance(uint256,address,bool)", listingId, allowedBuyer, true));
    }

    function buy(SchmackoSwap schmackoswap, address paymentToken, uint256 listingId) public returns (bool) {
        if (msg.sender != owner) revert("not owner");
        (,,,, uint256 price_,,) = schmackoswap.listings(listingId);

        paymentToken.call(abi.encodeWithSignature("approve(address,uint256)", address(schmackoswap), price_));
        (bool success,) = address(schmackoswap).call(abi.encodeWithSignature("fulfill(uint256)", listingId));
        return success;
    }

    function release(address ipnft, uint256 tokenId) public {
        if (msg.sender != owner) revert("not owner");
        (bool success,) = ipnft.call(abi.encodeWithSignature("safeTransferFrom(address,address,uint256,bytes)", address(this), owner, tokenId, ""));
        if (!success) revert("cant withdraw token");
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == this.onERC721Received.selector || super.supportsInterface(interfaceId);
    }
}

contract ContractReceiverTest is IPNFTMintHelper {
    address owner = makeAddr("contractowner");
    address buyer = makeAddr("buyer");
    address otherUser = makeAddr("otherUser");

    SchmackoSwap internal schmackoSwap;

    event Listed(uint256 listingId, SchmackoSwap.Listing listing);
    event Unlisted(uint256 listingId, SchmackoSwap.Listing listing);
    event Purchased(uint256 listingId, address indexed buyer, SchmackoSwap.Listing listing);
    event AllowlistUpdated(uint256 listingId, address indexed buyer, bool _isAllowed);

    IPNFT internal ipnft;
    IERC20 internal testToken;

    function setUp() public {
        vm.startPrank(deployer);
        ipnft = IPNFT(address(new ERC1967Proxy(address(new IPNFT()), "")));
        ipnft.initialize();

        mintpass = new Mintpass(address(ipnft));
        mintpass.grantRole(mintpass.MODERATOR(), deployer);
        ipnft.setAuthorizer(address(mintpass));
        schmackoSwap = new SchmackoSwap();

        FakeERC20 _testToken = new FakeERC20("Fakium", "FAKE20");
        _testToken.mint(buyer, 1 ether);
        testToken = IERC20(address(_testToken));

        vm.deal(owner, 0.05 ether);
        vm.stopPrank();
    }

    function testCanMintToERC721Receiver() public {
        dealMintpass(owner);
        vm.startPrank(owner);

        uint256 reservationId = ipnft.reserve();
        //this is obsolete now, we decided to mint using _mint, not _safeMint
        //BoringContractWallet boringWallet = new BoringContractWallet();
        //vm.expectRevert(bytes("ERC721: transfer to non ERC721Receiver implementer"));
        //ipnft.mintReservation{ value: MINTING_FEE }(address(boringWallet), reservationId, 1, arUri, DEFAULT_SYMBOL);
        CleverContractWallet wallet = new CleverContractWallet();
        ipnft.mintReservation{ value: MINTING_FEE }(address(wallet), reservationId, validationSignature, arUri, DEFAULT_SYMBOL);
        vm.stopPrank();

        assertEq(ipnft.ownerOf(1), address(wallet));
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
        ipnft.mintReservation{ value: MINTING_FEE }(address(wallet), reservationId, validationSignature, arUri, DEFAULT_SYMBOL);

        uint256 listingId = wallet.startSelling(address(schmackoSwap), address(ipnft), address(testToken), 1, address(buyerWallet));
        vm.stopPrank();

        (,, address creator_,, uint256 price_,,) = schmackoSwap.listings(listingId);
        assertEq(ipnft.ownerOf(1), address(wallet));
        assertEq(creator_, address(wallet));
        assertEq(price_, 1 ether);

        vm.startPrank(buyer);
        bool buyRes = buyerWallet.buy(schmackoSwap, address(testToken), listingId);
        assertEq(buyRes, true);

        assertEq(ipnft.balanceOf(address(wallet)), 0);
        assertEq(ipnft.ownerOf(1), address(buyerWallet));

        buyerWallet.release(address(ipnft), 1);
        assertEq(ipnft.balanceOf(address(buyerWallet)), 0);
        assertEq(ipnft.ownerOf(1), buyer);
        vm.stopPrank();
    }
}

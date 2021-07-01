import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, Contract, Signer } from "ethers";

describe("IPNFT contract", async () => {
  const MOCK_HASH = "152BE4A28CD60EB04EECBEF360B868524A1A149F";

  let nft: Contract;
  let owner: Signer;
  let user: Signer;

  let ownerAddress: string;
  let userAddress: string;

  beforeEach(async () => {
    const IPNFT = await ethers.getContractFactory("IPNFT");
    nft = await IPNFT.deploy("IPNFT", "IPNFT");
    [owner, user] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    userAddress = await user.getAddress();
  });

  describe("View functions", async () => {
    it("returns name properly", async () => {
  
     expect(await nft.name()).to.equal('IPNFT');
    });

    it("returns symbol properly", async () => {
      expect(await nft.symbol()).to.be.equal('IPNFT');
    });

    it("returns empty string for base URI",async () =>{
      const tokenId = 1;
      await nft.mint(
        ownerAddress,
        tokenId,
        ''
      );
      expect(await nft.tokenURI(tokenId)).to.be.equal('');
    });

    it("ownerOf returns the owner's address", async () => {
      const tokenId = 1;
      await nft.mint(
        ownerAddress,
        tokenId,
        MOCK_HASH
      );
      expect(await nft.ownerOf(tokenId)).to.equal(ownerAddress);
    });

    it("reverts if the owner of unminted NFTs is queried", async () => {
      await expect(nft.ownerOf(3))
        .to.be.revertedWith("ERC721: owner query for nonexistent token");
    });

    it("balanceOf returns balance of address on contract",async () => {
      const tokenId = 1;
      await nft.mint(
        ownerAddress,
        tokenId,
        MOCK_HASH
      );
      expect(await nft.balanceOf(ownerAddress)).to.equal(BigNumber.from("1"))
    });
    
    it("balanceOf returns 0 when no tokens are owned by the address", async () => {
      expect(await nft.balanceOf(userAddress)).to.equal(0);
    });

    it("tokenURI returns proper token URI",async () => {
      const tokenId = 1;
      await nft.mint(
        ownerAddress,
        tokenId,
        MOCK_HASH
      );
      expect(await nft.tokenURI(tokenId)).to.equal(MOCK_HASH);
    });

    it("isApprovedForAll returns of address is approved on all",async () => {
      const tokenId = 1;
      const isApproved = true;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.setApprovalForAll(userAddress,isApproved);
      expect(await nft.isApprovedForAll(ownerAddress,userAddress)).to.equal(isApproved);
    });

  });

  describe("Minting", async () => {
    it("should mint tokens to given address with URI", async () => {
      const tokenId = 1;
      await nft.mint(
        ownerAddress,
        tokenId,
        MOCK_HASH
      );
      expect(await nft.ownerOf(tokenId)).to.equal(ownerAddress);
    });

    it("should mint tokens to given address without URI", async () => {
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);

      expect(await nft.ownerOf(tokenId)).to.equal(ownerAddress);
    });
  });

  // Testing transactions

  describe("Transactions", async () => {
    it("transfer should revert transfer if item is not owned by account", async () => {
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await expect(
        nft.connect(user).transfer(ownerAddress, userAddress, 1)
      ).to.be.revertedWith("transfer caller is not owner nor approved");
    });

    it("transfer reverts when given tokenId does not exist", async () => {
      await expect(
        nft.connect(user).transfer(userAddress, ownerAddress, 2)
      ).to.be.revertedWith("operator query for nonexistent token");
    });

    it("transfer should transfer nft between different accounts", async () => {
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.connect(owner).transfer(ownerAddress, userAddress, tokenId);

      expect(await nft.balanceOf(ownerAddress)).to.equal(0);
      expect(await nft.balanceOf(userAddress)).to.equal(1);
    });

    it("transfer clears the approval for the token ID", async () => {
      const recipient = (await ethers.getSigners())[2];
      const recipientAddress = await recipient.getAddress();
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.approve(userAddress,tokenId);
      expect(await nft.getApproved(tokenId)).to.be.equal(userAddress);

      await nft.connect(owner).transfer(ownerAddress, recipientAddress, tokenId);
      expect(await nft.balanceOf(recipientAddress)).to.equal(BigNumber.from("1"));
      expect(await nft.ownerOf(tokenId)).to.equal(recipientAddress);
      expect(await nft.balanceOf(ownerAddress)).to.equal(ethers.constants.Zero);

      expect(await nft.getApproved(tokenId)).to.equal(ethers.constants.AddressZero);
    });

    it("transfer adjusts owner balances", async () => {
      const tokenId = 1;
      await nft.mint(
        ownerAddress,
        tokenId,
        MOCK_HASH
      );

      expect(await nft.balanceOf(ownerAddress)).to.equal(BigNumber.from("1"));
    });

    it("transferFrom",async () => {
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.connect(owner).transferFrom(ownerAddress, userAddress, tokenId);
      expect(await nft.ownerOf(tokenId)).to.equal(userAddress);
    });

    // it("safeTransferFrom",async () => {
    //   const tokenId = 1;
    //   await nft.mintWithoutTokenURI(ownerAddress, tokenId);
    //   await nft.connect(owner).safeTransferFrom(ownerAddress, userAddress, tokenId,"");
    //   expect(await nft.ownerOf(tokenId)).to.equal(userAddress);
    // })
  });

  describe("Approvals", async () => {
    it("approve", async () => {
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.approve(userAddress,tokenId);
      expect(await nft.getApproved(tokenId)).to.equal(userAddress);
      await nft.connect(user).transfer(ownerAddress, userAddress, tokenId);
      expect(await nft.ownerOf(tokenId)).to.be.equal(userAddress);
     
    });

    it("setApprovalForAll",async () => {
      const tokenId = 1;
      await nft.connect(owner).mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.connect(owner).setApprovalForAll(userAddress, true);
      expect(await nft.isApprovedForAll(ownerAddress, userAddress)).to.be.true;
      await nft.connect(user).transfer(ownerAddress, userAddress, tokenId);
      expect(await nft.ownerOf(tokenId)).to.be.equal(userAddress);
    });
  
    it("revoke approval for all", async () => {
      const tokenId = 1;
      await nft.mintWithoutTokenURI(ownerAddress, tokenId);
      await nft.connect(owner).setApprovalForAll(userAddress, true);
      expect(await nft.isApprovedForAll(ownerAddress, userAddress)).to.be.true;
      await nft.setApprovalForAll(userAddress, false);
      expect(await nft.isApprovedForAll(ownerAddress, userAddress)).to.be.false;
    });
  })

  describe("Events", async () => {

    it("emits Transfer properly", async () => {
      await nft.connect(owner).mint(ownerAddress, BigNumber.from("1"), MOCK_HASH);

      await expect(nft.connect(owner).transfer(ownerAddress, userAddress, BigNumber.from("1")))
        .to.emit(nft, "Transfer")
        .withArgs(ownerAddress, userAddress, BigNumber.from("1"));
    });

    it("emits Approval properly",async () => {
      await nft.connect(owner).mint(ownerAddress, BigNumber.from("1"), MOCK_HASH);
  
        await expect(nft.connect(owner).approve(userAddress,BigNumber.from("1")))
          .to.emit(nft, "Approval")
          .withArgs(ownerAddress, userAddress, BigNumber.from("1"));

    });

    it("emits ApprovalForAll properly",async () => {
      it("emits Approval properly",async () => {
        const isApproved = true;
        await nft.connect(owner).mint(ownerAddress, BigNumber.from("1"), MOCK_HASH);
    
        await expect(nft.connect(owner).approvalForAll(ownerAddress,userAddress,isApproved))
          .to.emit(nft, "ApprovalForAll")
          .withArgs(ownerAddress,userAddress,isApproved);
      });
    });
  })
});

const { expect } = require("chai");
const hre = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("IPNFT3525", function () {
  const arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";

  let ipnftContract;
  let mintpass;
  let deployer, alice, bob;

  beforeEach(async function () {
    [deployer, alice, bob] = await hre.ethers.getSigners();
  });

  it("deploys", async function () {
    const IPNFT = await ethers.getContractFactory("IPNFT3525V2");
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: "uups" });

    const Mintpass = await ethers.getContractFactory("Mintpass");
    mintpass = await Mintpass.deploy(ipnftContract.address);
    ipnftContract.connect(deployer).setMintpassContract(mintpass.address);

    const name = await ipnftContract.name();
    expect(name).to.equal("IP-NFT V2");
  });

  //this is the same as IPNFT3525.t.sol:testMinting
  it("can mint and generate metadata on chain", async function () {
    // Give bob a mintpass
    await mintpass.connect(deployer).batchMint(bob.address, 1);
    expect(await mintpass.ownerOf(1)).to.equal(bob.address);

    //bob mints 1 token for alice.
    await ipnftContract.connect(bob).reserve();
    await ipnftContract
      .connect(bob)
      .updateReservation(
        1,
        "IP Title",
        "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY"
      );

    await ipnftContract
      .connect(bob)
    ["mintReservation(address,uint256,uint256)"](alice.address, 1, 1);

    const tokenUri = await ipnftContract.tokenURI(1);

    const parts = tokenUri.split(",");

    expect(parts[0]).to.eq("data:application/json;base64");

    const jsonContent = Buffer.from(parts[1], "base64").toString();
    const metadata = JSON.parse(jsonContent);

    expect(metadata["name"]).to.eq("IP Title");
  });
});

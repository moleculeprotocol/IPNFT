const { expect } = require("chai");
const hre = require("hardhat");

describe("IPNFT fundamentals", function () {

  let ipnftContract;
  let mintpass;
  let deployer, alice, bob;

  beforeEach(async function () {
    [deployer, alice, bob] = await hre.ethers.getSigners();
  });

  it("deploys", async function () {
    const IPNFT = await ethers.getContractFactory("IPNFT");
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: "uups" });

    const Mintpass = await ethers.getContractFactory("Mintpass");
    mintpass = await Mintpass.deploy(ipnftContract.address);

    await (ipnftContract.connect(deployer)).setAuthorizer(mintpass.address);
  });

  it("validates updates", async function () {
    const result = await upgrades.validateUpgrade(
      ipnftContract.address,
      await ethers.getContractFactory("IPNFTV23"),
      {
        kind: "uups"
      }
    )
    //this didn't throw :)
    expect(1).to.eq(1)
  })

});
const { expect } = require("chai");
const hre = require("hardhat");

describe("IPNFT fundamentals and upgrades", function () {

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

  it("validates updates V21 -> V22", async function () {
    const IPNFTV21 = await ethers.getContractFactory("IPNFTV21");
    const ipnftContractV21 = await upgrades.deployProxy(IPNFTV21, { kind: "uups" });

    const result = await upgrades.validateUpgrade(
      ipnftContractV21.address,
      await ethers.getContractFactory("IPNFT"),
      {
        kind: "uups"
      }
    )
    //this didn't throw :)
    expect(1).to.eq(1)
  })

  it("validates updates to V23", async function () {
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

  it("validates frax upgrade", async function () {
    const Frac0 = await ethers.getContractFactory("Fractionalizer");
    const frac0 = await upgrades.deployProxy(Frac0, [hre.ethers.constants.AddressZero], { kind: "uups" });

    const result = await upgrades.validateUpgrade(
      frac0.address,
      await ethers.getContractFactory("FractionalizerNext"),
      {
        kind: "uups"
      }
    )
    //this didn't throw :)
    expect(1).to.eq(1)
  })


});
const { expect } = require("chai");
const hre = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("IPNFT3525", function () {

  const arUri = "ar://tNbdHqh3AVDHVD06P0OPUXSProI5kGcZZw8IvLkekSY";

  let ipnftContract;
  let deployer, alice, bob;


  beforeEach(async function () {
    [deployer, alice, bob] = await hre.ethers.getSigners();
  });

  it('deploys', async function () {
    const IPNFT = await ethers.getContractFactory('IPNFT3525');
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: 'uups' });

    const name = await ipnftContract.name()
    expect(name).to.equal("IP-NFT");

  });

  //this is the same as IPNFT3525.t.sol:testMinting
  it('can mint and generate metadata on chain', async function () {
    const fractions = [100];

    const ipnftArgs = hre.ethers.utils.defaultAbiCoder.encode(
      ["string", "string", "string", "uint64[]"],
      ["IP Title", "the description of that ip", arUri, fractions]
    )

    //just prove that our abiEncoder works as expected ;)
    const [name_, , , fractions_] = hre.ethers.utils.defaultAbiCoder.decode(
      ["string", "string", "string", "uint64[]"],
      ipnftArgs
    );

    expect(name_).to.equal("IP Title");
    expect(fractions_[0].toNumber()).to.equal(100);

    //bob mints 1 token for alice.
    await ipnftContract.connect(bob).mint(alice.address, ipnftArgs);

    const tokenUri = await ipnftContract.tokenURI(1);

    const parts = tokenUri.split(",");

    expect(parts[0]).to.eq("data:application/json;base64");

    const jsonContent = Buffer.from(parts[1], "base64").toString();
    const metadata = JSON.parse(jsonContent);

    expect(metadata['name']).to.eq("IP Title");
  })

});
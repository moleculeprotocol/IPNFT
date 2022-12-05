const { expect } = require("chai");
const hre = require("hardhat");

describe("IPNFT3525", function () {

  let ipnftContract;
  let mintpass;
  let deployer, alice, bob;

  beforeEach(async function () {
    [deployer, alice, bob] = await hre.ethers.getSigners();
  });

  it("deploys", async function () {
    const IPNFTMetadata = await ethers.getContractFactory("IPNFTMetadata");
    const _ipnftMetadata = await IPNFTMetadata.deploy();

    const IPNFT = await ethers.getContractFactory("IPNFT3525V2");
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: "uups" });

    const Mintpass = await ethers.getContractFactory("Mintpass");
    mintpass = await Mintpass.deploy(ipnftContract.address);
    await (ipnftContract.connect(deployer)).setMintpassContract(mintpass.address);
    await (ipnftContract.connect(deployer)).setMetadataGenerator(_ipnftMetadata.address);

    const name = await ipnftContract.name();
    expect(name).to.equal("IP-NFT V2");
  });

  //this is the same as IPNFT3525.t.sol:testMinting
  it("can mint and generate metadata on chain", async function () {
    // Give bob a mintpass
    await mintpass
        .connect(deployer)
        .grantRole(await mintpass.MODERATOR(), deployer.address);
    await mintpass.connect(deployer).batchMint(bob.address, 1);
    expect(await mintpass.ownerOf(1)).to.equal(bob.address);
  })

  //this is the same as IPNFT3525.t.sol:testMintFromReservation
  it("can mint an IP-NFT and generate metadata on chain", async function () {

    const imageUrl = "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU";
    const agreementUrl = "ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm";
    const projectDetailsUrl = "ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e";

    const encodedIpnftArgs = hre.ethers.utils.defaultAbiCoder.encode(
      ["string", "string", "string", "string", "string"],
      ["IP-NFT Test", "Some Description", imageUrl, agreementUrl, projectDetailsUrl]
    )

    //prove that our abiEncoder works as expected ;)
    const [decodedName_, , , , decodedDetailsUrl_] = hre.ethers.utils.defaultAbiCoder.decode(
      ["string", "string", "string", "string", "string"],
      encodedIpnftArgs
    );
    expect(decodedName_).to.eq("IP-NFT Test");
    expect(decodedDetailsUrl_).to.eq(projectDetailsUrl);

    const _ipnft = ipnftContract.connect(bob)

    await _ipnft.reserve();
    await _ipnft.updateReservation(
      1,
      encodedIpnftArgs
    );

    await _ipnft.mintReservation(alice.address, 1, 1, []);

    const tokenUri = await ipnftContract.tokenURI(1);

    expect(tokenUri.startsWith("data:application/json;base64")).to.be.true;
    const jsonContent = Buffer.from(tokenUri.replace("data:application/json;base64,", ""), "base64").toString();
    const metadata = JSON.parse(jsonContent);
    expect(metadata["name"]).to.eq("IP-NFT Test");
    expect(metadata["slot"]).to.eq(1);
    expect(metadata["properties"]).to.contain.key("external_url")
  });
});

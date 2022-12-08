const { expect } = require("chai");
const hre = require("hardhat");

//14gwei
const mainnetGasPrice = hre.ethers.BigNumber.from("14000000000");
const oneEthInDollar = 1235.0;

const logGas = (operation, receipt) => {

  const ethCosts = receipt.gasUsed.mul(mainnetGasPrice);
  const inEthers = parseFloat(hre.ethers.utils.formatEther(ethCosts))
  const inDollars = oneEthInDollar * inEthers;

  console.table([{ operation, gas: receipt.gasUsed.toString(), "Eth": inEthers, "$": inDollars }]);

}

const imageUrl = "ar://7De6dRLDaMhMeC6Utm9bB9PRbcvKdi-rw_sDM8pJSMU";
const agreementUrl = "ipfs://bafybeiewsf5ildpjbcok25trk6zbgafeu4fuxoh5iwjmvcmfi62dmohcwm";
const projectDetailsUrl = "ipfs://bafybeifhwj7gx7fjb2dr3qo4am6kog2pseegrnfrg53po55zrxzsc6j45e";

const encodedIpnftArgs = hre.ethers.utils.defaultAbiCoder.encode(
  ["string", "string", "string", "string", "string"],
  ["IP-NFT Test", "Some Description", imageUrl, agreementUrl, projectDetailsUrl]
)


describe("IPNFT3525 gas usage", function () {

  let ipnftContract;
  let mintpass;
  let deployer, alice, bob;

  beforeEach(async function () {
    [deployer, alice, bob, charlie] = await hre.ethers.getSigners();
  });

  it("deploys and deals mint passes", async function () {
    const IPNFTMetadata = await ethers.getContractFactory("IPNFTMetadata");
    const _ipnftMetadata = await IPNFTMetadata.deploy();

    const IPNFT = await ethers.getContractFactory("IPNFT3525V21");
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: "uups" });

    const Mintpass = await ethers.getContractFactory("Mintpass");
    mintpass = await Mintpass.deploy(ipnftContract.address);
    await (ipnftContract.connect(deployer)).setMintpassContract(mintpass.address);
    await (ipnftContract.connect(deployer)).setMetadataGenerator(_ipnftMetadata.address);

    const name = await ipnftContract.name();
    expect(name).to.equal("IP-NFT V2.1");

    await mintpass
      .connect(deployer)
      .grantRole(await mintpass.MODERATOR(), deployer.address);

    await mintpass.connect(deployer).batchMint(bob.address, 1);
    await mintpass.connect(deployer).batchMint(alice.address, 1);


  });


  it("can create a simple ERC3525 NFT", async function () {

    const _ipnft = ipnftContract.connect(bob)

    const reserveRes = await _ipnft.reserve();
    logGas("reserve slot", await reserveRes.wait());

    const updateRes = await _ipnft.updateReservation(
      1,
      encodedIpnftArgs
    );
    logGas("update reservation", await updateRes.wait());

    const mintRes = await _ipnft.mintReservation(alice.address, 1, 1, []);
    logGas("mint reservation", await mintRes.wait());


    const tokenUri = await ipnftContract.tokenURI(1);

    // expect(tokenUri.startsWith("data:application/json;base64")).to.be.true;
    const jsonContent = Buffer.from(tokenUri.replace("data:application/json;base64,", ""), "base64").toString();
    const metadata = JSON.parse(jsonContent);
    expect(metadata["name"]).to.eq("IP-NFT Test");
    expect(metadata["slot"]).to.eq(1);
    expect(metadata["properties"]).to.contain.key("external_url")
  });

  it("creates a fraction by sending value", async function () {
    const _ipnft = ipnftContract.connect(alice)

    const valueRes = await _ipnft['transferFrom(uint256,address,uint256)'](1, bob.address, 500_000);
    logGas("transfer value to a new user", await valueRes.wait())
    expect(await _ipnft["ownerOf(uint256)"](1)).to.eq(alice.address);
    expect(await _ipnft["ownerOf(uint256)"](2)).to.eq(bob.address);
  });

  it("transfers value from between existing tokens", async function () {
    const _ipnft = ipnftContract.connect(bob)

    const valueRes = await _ipnft['transferFrom(uint256,uint256,uint256)'](2, 1, 500_000);

    logGas("transfer value between existing SFTs", await valueRes.wait())

    expect((await _ipnft["balanceOf(uint256)"](1)).toString()).to.eq("1000000");
    expect((await _ipnft["balanceOf(uint256)"](2)).toString()).to.eq("0");
  });

  it("creates 10 fractional NFTs at once", async function () {
    const _ipnft = ipnftContract.connect(alice)
    const hdWallet = ethers.utils.HDNode.fromSeed(hre.ethers.utils.randomBytes(32));

    const ten = Array.from(Array(10).keys());
    const promises = ten.map(i => {
      return (async () => {

        const address = hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
        const res = await _ipnft['transferFrom(uint256,address,uint256)'](1, address, 1000);
        return res.wait();
      })()
    })
    const receipts = await Promise.all(promises);
    const gasCosts = receipts.reduce((acc, cur) => acc.add(cur.gasUsed),
      hre.ethers.BigNumber.from("0")
    );

    logGas("transfer to 10 new addresses", { gasUsed: gasCosts })
  })

  it("uses inline distribution for 100 addresses", async function () {
    const _ipnft = ipnftContract.connect(alice)
    const hdWallet = ethers.utils.HDNode.fromSeed(hre.ethers.utils.randomBytes(32));

    const hundred = Array.from(Array(100).keys());
    const addresses = hundred.map(i =>
      hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
    );
    const res = await (await _ipnft.distribute(1, addresses, 1000)).wait();

    logGas("distribute (inline) to 100 new addresses", res)
    expect((await _ipnft["balanceOf(uint256)"](88)).toString()).to.eq("1000");
  })

});

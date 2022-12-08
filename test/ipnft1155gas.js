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


describe("IPNFT1155 gas usage", function () {

  let ipnftContract;
  //  let mintpass;
  let deployer, alice, bob;

  beforeEach(async function () {
    [deployer, alice, bob, charlie] = await hre.ethers.getSigners();
  });

  it("deploys and mints the first nft", async function () {
    const _IPNFT = await ethers.getContractFactory("IPNFT");
    ipnftContract = await _IPNFT.deploy();

    // const name = await ipnftContract.name();
    // expect(name).to.equal("Foo");
    const mintRes = await ipnftContract.directMint(alice.address, projectDetailsUrl);
    logGas("mint an 1155 NFT", await mintRes.wait());
  });

  it("initializes fractions", async function () {
    const _ipnft = ipnftContract.connect(alice)

    const sharesRes = await _ipnft.increaseShares(0, 1_000_000, alice.address);
    logGas("mint all shares to the first owner", await sharesRes.wait());

  });

  it("transfer value to another account ", async function () {
    const _ipnft = ipnftContract.connect(alice)

    const res = await _ipnft.safeTransferFrom(alice.address, bob.address, 0, 500_000, []);
    logGas("transfer value between 2 accounts", await res.wait())

    expect((await _ipnft.balanceOf(alice.address, 0)).toString()).to.eq("500001");
    expect((await _ipnft.balanceOf(bob.address, 0)).toString()).to.eq("500000");
  });

  it("transfer to 10 accounts in a loop", async function () {
    const _ipnft = ipnftContract.connect(alice)
    const hdWallet = ethers.utils.HDNode.fromSeed(hre.ethers.utils.randomBytes(32));

    const ten = Array.from(Array(10).keys());
    // const addresses = ten.map(i =>
    //   hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
    // );

    const promises = ten.map(i => {
      return (async () => {

        const address = hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
        const res = await _ipnft.safeTransferFrom(alice.address, address, 0, 1000, []);
        //const res = await _ipnft['transferFrom(uint256,address,uint256)'](1, address, 1000);
        return res.wait();
      })()
    })

    const receipts = await Promise.all(promises);
    const gasCosts = receipts.reduce((acc, cur) => acc.add(cur.gasUsed),
      hre.ethers.BigNumber.from("0")
    );

    logGas("transfer to 10 new addresses", { gasUsed: gasCosts })
  })

  it("transfer to 100 accounts in a loop", async function () {
    const _ipnft = ipnftContract.connect(alice)
    const hdWallet = ethers.utils.HDNode.fromSeed(hre.ethers.utils.randomBytes(32));

    const hundred = Array.from(Array(100).keys());
    // const addresses = ten.map(i =>
    //   hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
    // );

    const promises = hundred.map(i => {
      return (async () => {

        const address = hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
        const res = await _ipnft.safeTransferFrom(alice.address, address, 0, 1000, []);
        //const res = await _ipnft['transferFrom(uint256,address,uint256)'](1, address, 1000);
        return res.wait();
      })()
    })

    const receipts = await Promise.all(promises);
    const gasCosts = receipts.reduce((acc, cur) => acc.add(cur.gasUsed),
      hre.ethers.BigNumber.from("0")
    );

    logGas("transfer to 100 new addresses", { gasUsed: gasCosts })
  })


  it("uses inline distribution for 100 addresses", async function () {
    const _ipnft = ipnftContract.connect(alice)
    const hdWallet = ethers.utils.HDNode.fromSeed(hre.ethers.utils.randomBytes(32));

    const hundred = Array.from(Array(100).keys());
    const addresses = hundred.map(i =>
      hdWallet.derivePath(`m/44'/60'/0'/0/${i}`).address
    );
    const res = await (await _ipnft.distribute(0, addresses, 100)).wait();

    logGas("distribute (inline) to 100 new addresses", res)
    expect((await _ipnft.balanceOf(addresses[88], 0)).toString()).to.eq("100");
  })

});

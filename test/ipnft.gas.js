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
const pepeUrl = "ipfs://bafybeidlr6ltzbipd6ix5ckyyzwgm2pbigx7ar2ht64v4czk65pkjouire/metadata.json";

describe("IPNFT1155 gas usage", function () {

  let ipnftContract;
  //  let mintpass;
  let deployer, alice, bob;

  beforeEach(async function () {
    [deployer, alice, bob, charlie] = await hre.ethers.getSigners();
  });

  it("deploys and mints the first nft", async function () {
    const IPNFT = await ethers.getContractFactory("IPNFTV21");
    //ipnftContract = await _IPNFT.deploy();
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: "uups" });

    const Mintpass = await ethers.getContractFactory("Mintpass");
    mintpass = await Mintpass.deploy(ipnftContract.address);
    await (ipnftContract.connect(deployer)).setAuthorizer(mintpass.address);
    await mintpass
      .connect(deployer)
      .grantRole(await mintpass.MODERATOR(), deployer.address);


    const passRes = await mintpass.connect(deployer).batchMint(alice.address, 10);
    logGas("mints 10 mint passes", await passRes.wait());

  });

  it("initializes fractions", async function () {
    const _ipnft = ipnftContract.connect(alice)

    await _ipnft.reserve();
    const mintRes = await _ipnft["mintReservation(address,uint256,uint256,string)"](alice.address, 1, 1, pepeUrl)
    logGas("mint an 1155 NFT", await mintRes.wait());

    const sharesRes = await _ipnft.increaseShares(1, 1_000_000, alice.address);
    logGas("mint all shares to the first owner", await sharesRes.wait());
  });

  it("transfer value to another account ", async function () {
    const _ipnft = ipnftContract.connect(alice)

    const res = await _ipnft.safeTransferFrom(alice.address, bob.address, 1, 500_000, []);
    logGas("transfer value between 2 accounts", await res.wait())

    expect((await _ipnft.balanceOf(alice.address, 1)).toString()).to.eq("500001");
    expect((await _ipnft.balanceOf(bob.address, 1)).toString()).to.eq("500000");
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
        const res = await _ipnft.safeTransferFrom(alice.address, address, 1, 1000, []);
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
        const res = await _ipnft.safeTransferFrom(alice.address, address, 1, 1000, []);
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
    const res = await (await _ipnft.distribute(1, addresses, 100)).wait();

    logGas("distribute (inline) to 100 new addresses", res)
    expect((await _ipnft.balanceOf(addresses[88], 1)).toString()).to.eq("100");
  })

});
const { ethers, upgrades } = require("hardhat");

//See https://github.com/HashHaran/foundry-upgrade-hardhat
async function main() {
  const IPNFT3525V1 = await ethers.getContractFactory("IPNFT3525");
  const ipnft3525v1 = await upgrades.deployProxy(IPNFT3525V1, [], { kind: 'uups', unsafeAllow: ['constructor'] });
  await ipnft3525v1.deployed();
  console.log(`IPNFT 3525 UUPS Proxy V1 is deployed to proxy address: ${ipnft3525v1.address}`);

  //upgrade: 
  // let versionAwareContractName = await uupsProxyPatternV1.getContractNameWithVersion();
  // console.log(`UUPS Pattern and Version: ${versionAwareContractName}`);

  // const UupsProxyPatternV2 = await ethers.getContractFactory("UupsProxyPatternV2");
  // const upgraded = await upgrades.upgradeProxy(uupsProxyPatternV1.address, UupsProxyPatternV2, {kind: 'uups', unsafeAllow: ['constructor'], call: 'initialize'});
  // console.log(`UUPS Proxy Pattern V2 is upgraded in proxy address: ${upgraded.address}`);

  // versionAwareContractName = await upgraded.getContractNameWithVersion();
  // console.log(`UUPS Pattern and Version: ${versionAwareContractName}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
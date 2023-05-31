const { expect } = require('chai')
const hre = require('hardhat')

describe('IPNFT fundamentals and upgrades', function () {
  let ipnftContract
  let mintpass
  let deployer, alice, bob

  beforeEach(async function () {
    ;[deployer, alice, bob] = await hre.ethers.getSigners()
  })

  it('deploys', async function () {
    const IPNFT = await ethers.getContractFactory('IPNFT')
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: 'uups' })

    const Mintpass = await ethers.getContractFactory('Mintpass')
    mintpass = await Mintpass.deploy(ipnftContract.address)

    await ipnftContract.connect(deployer).setAuthorizer(mintpass.address)
  })

  it('validates updates V23 -> V24', async function () {
    const IPNFTV23 = await ethers.getContractFactory('IPNFT')
    const ipnftContractV23 = await upgrades.deployProxy(IPNFTV23, {
      kind: 'uups'
    })

    const result = await upgrades.validateUpgrade(
      ipnftContractV23.address,
      await ethers.getContractFactory('IPNFTV24'),
      {
        kind: 'uups'
      }
    )
    //just make sure the above didn't throw :)
    expect(1).to.eq(1)
  })

  it('validates updates to V24', async function () {
    const result = await upgrades.validateUpgrade(
      ipnftContract.address,
      await ethers.getContractFactory('IPNFTV24'),
      {
        kind: 'uups'
      }
    )
    //just make sure the above didn't throw :)
    expect(1).to.eq(1)
  })

  it('validates fractionalizer upgrade', async function () {
    const Frac0 = await ethers.getContractFactory('Fractionalizer')
    const frac0 = await upgrades.deployProxy(
      Frac0,
      [hre.ethers.constants.AddressZero],
      { kind: 'uups' }
    )

    const result = await upgrades.validateUpgrade(
      frac0.address,
      await ethers.getContractFactory('FractionalizerNext'),
      {
        kind: 'uups'
      }
    )
    //just make sure the above didn't throw :)
    expect(1).to.eq(1)
  })
})

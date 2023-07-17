const { expect } = require('chai')
const hre = require('hardhat')

describe('IPNFT fundamentals and upgrades', function () {
  let ipnftContract
  let authorizer
  let deployer, alice, bob

  beforeEach(async function () {
    ;[deployer, alice, bob] = await hre.ethers.getSigners()
  })

  it('deploys', async function () {
    const IPNFT = await ethers.getContractFactory('IPNFT')
    ipnftContract = await upgrades.deployProxy(IPNFT, { kind: 'uups' })

    const SignedMintAuthorizer = await ethers.getContractFactory(
      'SignedMintAuthorizer'
    )
    authorizer = await SignedMintAuthorizer.deploy(deployer.address)

    await ipnftContract.connect(deployer).setAuthorizer(authorizer.address)
  })

  it('validates updates V23 -> V24 -> V25', async function () {
    const IPNFTV23 = await ethers.getContractFactory('IPNFTV23')
    const ipnftContractV23 = await upgrades.deployProxy(IPNFTV23, {
      kind: 'uups'
    })

    const result = await upgrades.validateUpgrade(
      ipnftContractV23.address,
      await ethers.getContractFactory('IPNFT'),
      {
        kind: 'uups'
      }
    )
    //just make sure the above didn't throw :)
    expect(1).to.eq(1)

    const result25 = await upgrades.validateUpgrade(
      ipnftContractV23.address,
      await ethers.getContractFactory('IPNFTV25'),
      {
        kind: 'uups'
      }
    )
    expect(1).to.eq(1)
  })

  it('validates synthesizer upgrade', async function () {
    const Synth0 = await ethers.getContractFactory('Synthesizer')
    const synth0 = await upgrades.deployProxy(
      Synth0,
      [hre.ethers.constants.AddressZero, hre.ethers.constants.AddressZero],
      { kind: 'uups' }
    )

    const result = await upgrades.validateUpgrade(
      synth0.address,
      await ethers.getContractFactory('Tokenizer'),
      {
        kind: 'uups'
      }
    )
    //just make sure the above didn't throw :)
    expect(1).to.eq(1)
  })
})

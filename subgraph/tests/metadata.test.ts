import { ipfs } from "@graphprotocol/graph-ts"
import { assert, describe, mockIpfsFile, test } from 'matchstick-as/assembly/index'
import { handleMetadata } from '../src/metadataMapping'

const IPNFT_METADATA = "IpnftMetadata"

describe('Metadata', () => {
    //https://thegraph.com/docs/en/subgraphs/developing/creating/unit-testing-framework/#mocking-ipfs-files-from-matchstick-041
  
    test('reads ipnft metadata', () => {
  
      mockIpfsFile('ipfsCatBaseIpnft', 'tests/fixtures/ipnft_1.json')
      
      let rawData = ipfs.cat("ipfsCatBaseIpnft")
      if (!rawData) {
        throw new Error("Failed to fetch ipfs data")
      }
      
      handleMetadata(rawData)
      assert.entityCount(IPNFT_METADATA, 1)
      assert.fieldEquals(IPNFT_METADATA, '', 'topic', 'Wormholes')
      assert.fieldEquals(IPNFT_METADATA, '', 'fundingAmount_value', '1234.5678')
      assert.fieldEquals(IPNFT_METADATA, '', 'fundingAmount_currency', 'USD')

      //logStore()
    })
})


import axios from 'axios'
import { ActionFn, Context, Event, TransactionEvent } from '@tenderly/actions'

const CROWDSALE_CONTRACT_MAINNET = '0x35Bce29F52f51f547998717CD598068Afa2B29B7'
const CROWDSALE_CONTRACT_GOERLI = '0x46c3369dEce07176Ad7164906D3593AA4C126d35'
const TOPIC0 =
  '0xdcd726e11f8b5e160f00290f0fe3a1abb547474e53a8e7a8f49a85e7b1ca3199'

const CROWDSALE_BIDS_QUERY_ID = '2709374'
const CUMULATIVE_BIDS_QUERY_ID = '2709364'

const triggerDuneQuery: ActionFn = async (context: Context, event: Event) => {
  const apiToken = await context.secrets.get('DUNE_API_KEY')
  const txEvent = event as TransactionEvent

  txEvent.network === '5'
    ? CROWDSALE_CONTRACT_GOERLI
    : CROWDSALE_CONTRACT_MAINNET

  console.log(txEvent.logs)
  const placeBidLog = txEvent.logs.find((log) => log.topics[0] === TOPIC0)

  if (!placeBidLog) return

  const saleId = BigInt(placeBidLog.topics[1]).toString()
  const queryIds = [CROWDSALE_BIDS_QUERY_ID, CUMULATIVE_BIDS_QUERY_ID]

  const queryParameters = {
    saleId: saleId,
    chain: txEvent.network === '5' ? 'ipnft_goerli' : 'ipnft_ethereum'
  }

  for (const queryId of queryIds) {
    try {
      const res = await axios.post(
        `https://api.dune.com/api/v1/query/${queryId}/execute`,
        {
          query_parameters: queryParameters
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'X-Dune-API-Key': apiToken
          }
        }
      )
      console.log('response >> ', res.data)
    } catch (e) {
      console.log('error >> ', e)
    }
  }
}

module.exports = { triggerDuneQuery }

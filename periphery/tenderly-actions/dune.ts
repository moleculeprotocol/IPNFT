import { ActionFn, Context, TransactionEvent, Event } from '@tenderly/actions'
import axios from 'axios'

const triggerDuneQuery: ActionFn = async (context: Context, event: Event) => {
  const transactionEvent = event as TransactionEvent
  // keccak256(Bid(uint256 saleId,address bidder,uint256 amount));
  const BID_EVENT_SIG =
    '0xdcd726e11f8b5e160f00290f0fe3a1abb547474e53a8e7a8f49a85e7b1ca3199'

  const placeBidLog = transactionEvent.logs.find(
    (log) => log.topics[0] === BID_EVENT_SIG
  )
  if (!placeBidLog) return

  const saleId = BigInt(placeBidLog.topics[1]).toString()
  const DUNE_API_KEY = await context.secrets.get('DUNE_API_KEY')

  //[Cumulative Bids, CrowdSale Bids, Plain Crowdsale Cumulative Bids, Plain Crowdsale Bids]
  const duneQueryIds = [2709374, 2709364, 4186294, 4186293]

  const query_parameters = {
    saleId: saleId,
    chain: transactionEvent.network === '11155111' ? 'sepolia' : 'ethereum'
  }

  for (const queryId of duneQueryIds) {
    try {
      const res = await axios.post(
        `https://api.dune.com/api/v1/query/${queryId}/execute`,
        {
          query_parameters
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'X-Dune-API-Key': DUNE_API_KEY
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

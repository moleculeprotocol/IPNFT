import axios from 'axios'

const triggerDuneQuery = async (context, event) => {
  const bid_event_hash = await context.storage.getJson('BID_EVENT_HASH')
  const placeBidLog = event.logs.find((log) => log.topics[0] === bid_event_hash)

  if (!placeBidLog) return
  const saleId = BigInt(placeBidLog.topics[1]).toString()
  const apiToken = await context.secrets.get('DUNE_API_KEY')
  const queryIds = await Promise.all([
    context.storage.getJson('CROWDSALE_BIDS_QUERY_ID'),
    context.storage.getJson('CUMULATIVE_BIDS_QUERY_ID')
  ])

  const queryParameters = {
    saleId: saleId,
    chain: event.network === '5' ? 'ipnft_goerli' : 'ipnft_ethereum'
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

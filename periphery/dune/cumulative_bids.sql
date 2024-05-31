SELECT
  bids.evt_block_time,
  SUM(previous_bids.amount) / 1e18 AS cumulative_growth
FROM 
  ipnft_{{chain}}.StakedLockingCrowdSale_evt_Bid as bids
LEFT JOIN ipnft_{{chain}}.StakedLockingCrowdSale_evt_Bid 
  AS previous_bids 
  ON previous_bids.evt_block_time <= bids.evt_block_time
  AND previous_bids.saleId = cast('{{saleId}}' as uint256)
WHERE
  bids.saleId = cast('{{saleId}}' as uint256)
GROUP BY
  bids.evt_block_time,
  bids.amount
ORDER BY
  bids.evt_block_time;
SELECT
  current_bid.evt_block_time,
  SUM(previous_bids.amount) / 1e18 AS cumulative_growth
FROM
  {{chain}}.StakedLockingCrowdSale_evt_Bid AS current_bid
  LEFT JOIN {{chain}}.StakedLockingCrowdSale_evt_Bid AS previous_bids ON previous_bids.evt_block_time < current_bid.evt_block_time
WHERE
  current_bid.saleId = cast('{{saleId}}' as uint256)
GROUP BY
  current_bid.evt_block_time,
  current_bid.amount
ORDER BY
  current_bid.evt_block_time;
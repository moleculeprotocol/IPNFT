with bids as (
  SELECT
      Bidder as bidder,
      sum(amount) as bid_size
    FROM
      ipnft_{{chain}}.StakedLockingCrowdSale_evt_Bid
    WHERE
      saleId = cast('{{saleId}}' as uint256)
    GROUP BY
      Bidder,
      amount
    ORDER BY
      bid_size DESC
),
decimals as (SELECT tokens.decimals
    FROM
    (
    SELECT from_hex(json_extract_scalar(sale, '$.biddingToken')) as biddingTokenContract
    FROM
      ipnft_{{chain}}.StakedLockingCrowdSale_evt_Started
    WHERE
      saleId = cast('{{saleId}}' as uint256)
    ) as sale
      LEFT JOIN prices.tokens as tokens 
      ON tokens.blockchain = '{{chain}}' 
      AND tokens.contract_address = sale.biddingTokenContract
  )
  select 
    Bidder,
    bid_size / pow(10, decimals) as bid_amount
  FROM bids, decimals
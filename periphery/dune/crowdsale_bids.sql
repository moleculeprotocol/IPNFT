with
  data as (
    SELECT
      Bidder,
      amount as bid_size
    FROM
      {{chain}}.StakedLockingCrowdSale_evt_Bid
    WHERE
      saleId = cast('{{saleId}}' as uint256)
    GROUP BY
      Bidder,
      amount
    ORDER BY
      bid_size DESC
  ),
  token as (
    SELECT
      json_extract_scalar(sale, '$.biddingToken') as biddingToken
    FROM
      {{chain}}.StakedLockingCrowdSale_evt_Started
    WHERE
      saleId = cast('{{saleId}}' as uint256)
  ),
  token_with_decimals as (
    SELECT
      biddingToken,
      decimals
    FROM
      token
      JOIN tokens.erc20 ON from_hex(biddingToken) = contract_address
  )
SELECT
  Bidder,
  bid_size / pow(10, decimals) as adjusted_bid_size
FROM
  data
  CROSS JOIN token_with_decimals
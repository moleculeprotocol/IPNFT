# Scope

Some points an auditor should take particular care of the contracts that capture and distribute value:

- `Fractionalizer`
- `FractionalizedToken`
- `StakedVestedCrowdSale` and its linear ancestors that provide the mandatory functionality:
- `VestedCrowdSale`
- `CrowdSale`

Note that `Fractionalizer` has a strict coupling to an the underyling ERC1155 `IPFNT` contract, but that one can be considered a "general" ERC1155 and isn't necessarily in scope of this analysis.

- look out for any condition that would allow attackers to steal funds from the crowdsale contract or lock significant amounts of tokens in it forever

- gas implications aren't a major concern but if there are obvious optimization recommendations we happily apply them

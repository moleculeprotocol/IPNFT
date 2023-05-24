Some points to take particular care of:

- The main focus should lie on the `Fractionalizer`, `FractionalizedToken` and `StakedVestedCrowdSale` contracts, since those are the ones that capture and distribute value.

- The strict coupling of IPNFT, Schmackoswap and Fractionalizer is not ideal but allows us to trust the individual components.

- gas implications aren't a major concern but if there are obvious optimization recommendations we happily take them

- particular focus should by put on any condition that'd allow attackers to steal funds from the crowdsale contract or lock significant amounts of tokens in it forever

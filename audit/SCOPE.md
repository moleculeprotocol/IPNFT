Some points to take particular care of:

- The main focus should lie on the `Fractionalizer` contract and its spawned ERC20 token instances, since those are the ones that capture and distribute value.
- The strict coupling of IPNFT, Schmackoswap and Fractionalizer is not ideal but allows us to trust the individual components.
- The claiming phases that follow a sales process make assumptions over who's allowed to invoke them. We must ensure that no untrusted party can simply start a claiming process with "value 0". We can assume the IPNFT holder as trustful but it's an open question whether that's true forever.
- the computation of claiming amounts (Fractionalizer:claimableTokens) is pretty simply but prone to arithmetic overflows when someone chooses too high fraction supplies and sales amounts in combination. We covered that with a fuzz test but maybe we overlooked something here
- gas implications aren't a major concern but if there are obvious optimization recommendations we happily take them

```mermaid
sequenceDiagram
    participant OO as OriginalOwner
    participant Fractionalizer
    participant FracToken as FracTokenContract
    participant FracHolder
    participant SOS as SchmackoSwap
    participant Buyer as IPNFTBuyer

    OO->>Fractionalizer: fractionalizeIpnft()
    Fractionalizer->>FracToken: new FractionalizedToken instance
    FracToken->>OO: issue initial amount

    OO->>FracHolder: transfers fractions, e.g. by Crowdsale

    OO->>FracToken: issue()
    FracToken->>OO: mints new tokens to OO

    par sell IPNFT with FractionalizedToken as beneficiary
        OO->>SOS: approve all IPNFTs
        OO->>SOS: list IPNFT for amt/USDC for FractionalizerContract
        Buyer->>SOS: pay list price amt
        SOS->>FracToken: transfers payment funds
        OO->>Buyer: transfers IPNFT
    end

    alt sale via SchmackoSwap
        OO->>Fractionalizer: afterSale(listingId)
        Note left of Fractionalizer: can be called by any observer
        Fractionalizer->>SOS: check sales occurred with  Fractionalizer as beneficiary
    else custom sale
        OO->>Fractionalizer: afterSale(fractionId, paymentToken, amount)
        OO->>FracToken: transfers payment funds
        Note left of Fractionalizer: can only be called by the seller
    end

    Fractionalizer->>Fractionalizer: start claiming phase

    FracHolder->>FracToken: burn(signature)
    FracToken->>Fractionalizer: verifies signature
    FracToken->>Fractionalizer: checks FracHolder share amt
    FracToken->>FracToken: burns all FracHolder shares
    FracToken->>FracHolder: transfers share of payment token


```

import { Bytes, log } from "@graphprotocol/graph-ts";
import { Ipnft, Listing } from "../generated/schema";
import {
    AllowlistUpdated as AllowlistUpdatedEvent,
    Listed as ListedEvent,
    Purchased as PurchasedEvent,
    Unlisted as UnlistedEvent
} from "../generated/SchmackoSwap/SchmackoSwap";

export function handleListed(event: ListedEvent): void {
    let listing = new Listing(event.params.listingId.toString());
    let ipnft = Ipnft.load(event.params.listing.tokenId.toString());
    if (!ipnft) {
        log.debug("Could not load ipnft from tokenId", []);
    } else {
        listing.ipnft = ipnft.id;
    }

    listing.creator = event.params.listing.creator;
    listing.paymentToken = event.params.listing.paymentToken;
    listing.askPrice = event.params.listing.askPrice;
    listing.createdAt = event.block.timestamp;
    listing.allowlist = [];

    listing.save();
}

export function handleUnlisted(event: UnlistedEvent): void {
    let listing = Listing.load(event.params.listingId.toString());
    if (!listing) {
        log.debug(
            `could not load listing from listingId: ${event.params.listingId.toString()}`,
            []
        );
    } else {
        listing.unlistedAt = event.block.timestamp;

        listing.save();
    }
}

export function handleAllowlistUpdated(event: AllowlistUpdatedEvent): void {
    let listing = Listing.load(event.params.listingId.toString());
    if (!listing) {
        log.debug(
            `could not load listing from tokenId: ${event.params.listingId.toString()}`,
            []
        );
        return;
    }

    if (event.params._isAllowed === true) {
        listing.allowlist.push(event.params.buyer);
    } else {
        let newAllowlist: Bytes[] = [];
        for (let i = 0; i < listing.allowlist.length; i++) {
            if (listing.allowlist[i] == event.params.buyer) {
                newAllowlist.push(listing.allowlist[i]);
            }
        }
        listing.allowlist = newAllowlist;
    }

    listing.save();
}

export function handlePurchased(event: PurchasedEvent): void {
    let listing = Listing.load(event.params.listingId.toString());
    if (!listing) {
        log.debug(
            `could not load listing from listingId: ${event.params.listingId.toString()}`,
            []
        );
        return;
    }

    listing.purchasedAt = event.block.timestamp;
    listing.buyer = event.params.buyer;
    listing.save();
}

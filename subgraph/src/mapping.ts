import { Address, Bytes, log, store } from '@graphprotocol/graph-ts';
import {
    IPNFT,
    TransferSingle as TransferSingleEvent,
    Reserved as ReservedEvent,
    TokenMinted as TokenMintedEvent,
    ReservationURIUpdated as ReservationURIUpdatedEvent,
} from '../generated/IPNFT/IPNFT';
import {
    Listed as ListedEvent,
    Unlisted as UnlistedEvent,
    Purchased as PurchasedEvent,
    AllowlistUpdated as AllowlistUpdatedEvent,
} from '../generated/SchmackoSwap/SchmackoSwap';
import { Ipnft, Listing, Reservation } from '../generated/schema';

export function handleReservation(event: ReservedEvent): void {
    let reservation = new Reservation(event.params.reservationId.toString());
    reservation.owner = event.params.reserver;
    reservation.createdAt = event.block.timestamp;
    reservation.save();
}

export function handleReservationURIUpdate(
    event: ReservationURIUpdatedEvent
): void {
    const reservation = Reservation.load(event.params.reservationId.toString());
    if (!reservation) {
        log.debug(
            `could not load reservation from reservationId: ${event.params.reservationId.toString()}`,
            []
        );
    } else {
        reservation.uri = event.params.tokenURI;
        reservation.save();
    }
}

export function handleMint(event: TokenMintedEvent): void {
    let ipnft = new Ipnft(event.params.tokenId.toString());
    ipnft.owner = event.params.owner;
    ipnft.createdAt = event.block.timestamp;
    ipnft.tokenURI = event.params.tokenURI;
    ipnft.save();

    store.remove('Reservation', event.params.tokenId.toString());
}

export function handleListed(event: ListedEvent): void {
    let listing = new Listing(event.params.listingId.toString());
    let ipnft = Ipnft.load(event.params.listing.tokenId.toString());
    if (!ipnft) {
        log.debug('Could not load ipnft from tokenId', []);
    } else {
        listing.ipnft = ipnft.id;
    }

    listing.creator = event.params.listing.creator;
    listing.tokenSupply = event.params.listing.tokenAmount;
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

export function handleTransfer(event: TransferSingleEvent): void {
    // Do not handle Mints as they are handled by the handleMint function
    if (
        event.params.from !==
        Address.fromString('0x0000000000000000000000000000000000000000')
    ) {
        let ipnft = Ipnft.load(event.params.id.toString());
        if (ipnft) {
            ipnft.owner = event.params.to;
            ipnft.save();
        }
    }
}

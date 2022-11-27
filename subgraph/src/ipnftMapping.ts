import { Address, log, store } from "@graphprotocol/graph-ts";
import {
    ReservationURIUpdated as ReservationURIUpdatedEvent,
    Reserved as ReservedEvent,
    TokenMinted as TokenMintedEvent,
    TransferSingle
} from "../generated/IPNFT/IPNFT";
import { Ipnft, Reservation } from "../generated/schema";

export function handleTransferSingle(event: TransferSingle): void {
    if (event.params.from !== Address.zero()) {
        let ipnft = Ipnft.load(event.params.id.toString());
        if (ipnft) {
            ipnft.owner = event.params.to;
            ipnft.save();
        }
    }
}

export function handleReservation(event: ReservedEvent): void {
    let reservation = new Reservation(event.params.reservationId.toString());
    reservation.owner = event.params.reserver;
    reservation.createdAt = event.block.timestamp;
    reservation.save();
}

export function handleReservationURIUpdated(
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
    ipnft.createdAt = event.block.timestamp;
    ipnft.save();

    store.remove("Reservation", event.params.tokenId.toString());
}

import { Address, log, store } from "@graphprotocol/graph-ts";
import {
    ReservationUpdated,
    Reserved,
    IPNFTMinted,
    Transfer
} from "../generated/IPNFT3525V2/IPNFT3525V2";
import { Ipnft, Reservation } from "../generated/schema";

export function handleTransfer(event: Transfer): void {
    if (event.params.from !== Address.zero()) {
        let ipnft = Ipnft.load(event.params.tokenId.toString());
        if (ipnft) {
            ipnft.owner = event.params.to;
            ipnft.save();
        }
    }
}

export function handleReservation(event: Reserved): void {
    let reservation = new Reservation(event.params.reservationId.toString());
    reservation.owner = event.params.reserver;
    reservation.createdAt = event.block.timestamp;
    reservation.save();
}

export function handleReservationUpdated(event: ReservationUpdated): void {
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

export function handleMint(event: IPNFTMinted): void {
    let ipnft = new Ipnft(event.params.tokenId.toString());
    ipnft.owner = event.params.minter;
    ipnft.tokenURI = event.params.tokenURI;
    ipnft.createdAt = event.block.timestamp;
    ipnft.save();

    store.remove("Reservation", event.params.tokenId.toString());
}

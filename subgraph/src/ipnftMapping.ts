import { Address, store } from "@graphprotocol/graph-ts";
import {
    IPNFTMinted as IPNFTMintedEvent,
    Reserved as ReservedEvent,
    SymbolUpdated as SymbolUpdatedEvent,
    TransferSingle as TransferSingleEvent
} from "../generated/IPNFT/IPNFT";
import { Ipnft, Reservation } from "../generated/schema";

export function handleTransferSingle(event: TransferSingleEvent): void {
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

export function handleMint(event: IPNFTMintedEvent): void {
    let ipnft = new Ipnft(event.params.tokenId.toString());
    ipnft.owner = event.params.owner;
    ipnft.tokenURI = event.params.tokenURI;
    ipnft.createdAt = event.block.timestamp;
    ipnft.save();

    store.remove("Reservation", event.params.tokenId.toString());
}

export function handleSymbolUpdated(event: SymbolUpdatedEvent): void {
    let ipnft = Ipnft.load(event.params.tokenId.toString());
    if (ipnft) {
        ipnft.symbol = event.params.symbol;
        ipnft.save();
    }
}

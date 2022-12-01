import {
    Address,
    BigInt,
    Bytes,
    json,
    log,
    store
} from "@graphprotocol/graph-ts";
import {
    IPNFT3525V2 as IPNFTContract,
    IPNFTMinted,
    ReservationUpdated,
    Reserved,
    Transfer
} from "../generated/IPNFT3525V2/IPNFT3525V2";
import { Ipnft, Reservation } from "../generated/schema";
import { decode } from "./lib/b64";

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
        reservation.name = event.params.name;
        reservation.save();
    }
}

//todo V2.1: check if we have to create a slot and create it
export function handleMint(event: IPNFTMinted): void {
    store.remove("Reservation", event.params.tokenId.toString());

    let ipnft = new Ipnft(event.params.tokenId.toString());
    ipnft.owner = event.params.minter;
    ipnft.createdAt = event.block.timestamp;

    const ipnftContract = IPNFTContract.bind(event.address);
    let metadatab64: string = ipnftContract.tokenURI(event.params.tokenId);

    let _metadata = json.try_fromBytes(
        Bytes.fromUint8Array(
            decode(metadatab64.replace("data:application/json;base64,", ""))
        )
    );

    if (_metadata.isError) {
        ipnft.save();
        return;
    }

    let metadata = _metadata.value.toObject();

    let name = metadata.get("name");
    let image = metadata.get("image");
    let description = metadata.get("description");

    let balance = metadata.get("balance");
    let slotId = metadata.get("slot");

    if (image) {
        ipnft.image = image.toString();
    }
    if (name) {
        ipnft.name = name.toString();
    }
    if (description) {
        ipnft.description = description.toString();
    }
    if (balance) {
        ipnft.balance = BigInt.fromString(balance.toString());
    }

    if (slotId) {
        ipnft.slotId = slotId.toBigInt().toString();
    }

    let properties = metadata.get("properties");
    if (properties) {
        let props = properties.toObject();
        let agreement_url = props.get("agreement_url");
        let project_details_url = props.get("project_details_url");
        let external_url = props.get("external_url");

        if (agreement_url) {
            ipnft.agreement_url = agreement_url.toString();
        }

        if (project_details_url) {
            ipnft.project_details_url = project_details_url.toString();
        }

        if (external_url) {
            ipnft.external_url = external_url.toString();
        }
    }

    ipnft.save();
}

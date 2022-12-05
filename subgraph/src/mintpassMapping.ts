import { Address, log, store } from "@graphprotocol/graph-ts";
import {
    Redeemed as RedeemedEvent,
    Revoked as RevokedEvent,
    Transfer as TransferEvent
} from "../generated/Mintpass/Mintpass";
import { Mintpass } from "../generated/schema";

export function handleTransfer(event: TransferEvent): void {
    if (event.params.from == Address.zero()) {
        //mint
        let mintpass = new Mintpass(event.params.tokenId.toString());
        mintpass.owner = event.params.to;
        mintpass.createdAt = event.block.timestamp;
        mintpass.status = "DEFAULT";
        mintpass.save();
    } else if (event.params.to == Address.zero()) {
        //burn
        store.remove("Mintpass", event.params.tokenId.toString());
    }
}

export function handleRevoked(event: RevokedEvent): void {
    let mintpass = Mintpass.load(event.params.tokenId.toString());
    if (!mintpass) {
        log.warning(
            `could not load mintpass ${event.params.tokenId.toString()}`,
            []
        );
        return;
    }
    mintpass.status = "REVOKED";
    mintpass.save();
}

export function handleRedeemed(event: RedeemedEvent): void {
    let mintpass = Mintpass.load(event.params.tokenId.toString());
    if (!mintpass) {
        log.warning(
            `could not load mintpass ${event.params.tokenId.toString()}`,
            []
        );
        return;
    }
    mintpass.status = "REDEEMED";
    mintpass.save();
}

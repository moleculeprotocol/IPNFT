import { log, store } from "@graphprotocol/graph-ts";
import {
    Revoked as RevokedEvent,
    TokenMinted as TokenMintedEvent,
    TokenBurned as TokenBurnedEvent
} from "../generated/Mintpass/Mintpass";
import { Mintpass } from "../generated/schema";

export function handleTokenMinted(event: TokenMintedEvent): void {
    let mintpass = new Mintpass(event.params.tokenId.toString());
    mintpass.owner = event.params.owner;
    mintpass.createdAt = event.block.timestamp;
    mintpass.valid = true;
    mintpass.save();
}

export function handleRevoked(event: RevokedEvent): void {
    let mintpass = Mintpass.load(event.params.tokenId.toString());
    if (!mintpass) {
        log.debug(
            `could not load mintpass from tokenid: ${event.params.tokenId.toString()}`,
            []
        );
    } else {
        mintpass.valid = false;
        mintpass.save();
    }
}

export function handleTokenBurned(event: TokenBurnedEvent): void {
    store.remove("Mintpass", event.params.tokenId.toString());
}

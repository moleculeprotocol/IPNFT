import { Address, ByteArray, store } from '@graphprotocol/graph-ts'
import { crypto } from '@graphprotocol/graph-ts'
import {
  IPNFTMinted as IPNFTMintedEvent,
  Reserved as ReservedEvent,
  SymbolUpdated as SymbolUpdatedEvent,
  ReadAccessGranted as ReadAccessGrantedEvent,
  TransferSingle as TransferSingleEvent
} from '../generated/IPNFT/IPNFT'
import { Ipnft, Reservation, CanRead } from '../generated/schema'

export function handleTransferSingle(event: TransferSingleEvent): void {
  if (event.params.from !== Address.zero()) {
    let ipnft = Ipnft.load(event.params.id.toString())
    if (ipnft) {
      ipnft.owner = event.params.to
      ipnft.save()
    }
  }
}

export function handleReadAccess(event: ReadAccessGrantedEvent): void {
  let ipnft = Ipnft.load(event.params.tokenId.toString())
  if (!ipnft) {
    return
  }

  const canReadIdBytes = new ByteArray(32 + 20)
  canReadIdBytes.set(event.params.tokenId, 0)
  canReadIdBytes.set(event.params.reader, 32)
  const canReadId = crypto.keccak256(canReadIdBytes).toHexString()

  let canRead = new CanRead(canReadId)
  canRead.ipnft = ipnft.id
  canRead.reader = event.params.reader
  canRead.until = event.params.until

  canRead.save()
}

export function handleReservation(event: ReservedEvent): void {
  let reservation = new Reservation(event.params.reservationId.toString())
  reservation.owner = event.params.reserver
  reservation.createdAt = event.block.timestamp
  reservation.save()
}

export function handleMint(event: IPNFTMintedEvent): void {
  let ipnft = new Ipnft(event.params.tokenId.toString())
  ipnft.owner = event.params.owner
  ipnft.tokenURI = event.params.tokenURI
  ipnft.createdAt = event.block.timestamp
  ipnft.save()

  store.remove('Reservation', event.params.tokenId.toString())
}

export function handleSymbolUpdated(event: SymbolUpdatedEvent): void {
  let ipnft = Ipnft.load(event.params.tokenId.toString())
  if (ipnft) {
    ipnft.symbol = event.params.symbol
    ipnft.save()
  }
}

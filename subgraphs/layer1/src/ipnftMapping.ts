import {
  Address,
  ByteArray,
  crypto,
  ethereum,
  store
} from '@graphprotocol/graph-ts';

import {
  IPNFTMinted as IPNFTMintedEvent,
  Reserved as ReservedEvent,
  SymbolUpdated as SymbolUpdatedEvent,
  ReadAccessGranted as ReadAccessGrantedEvent,
  TransferSingle as TransferSingleEvent
} from '../generated/IPNFT/IPNFT';
import { Ipnft, Reservation, CanRead } from '../generated/schema';

export function handleTransferSingle(event: TransferSingleEvent): void {
  if (event.params.from !== Address.zero()) {
    let ipnft = Ipnft.load(event.params.id.toString());
    if (ipnft) {
      ipnft.owner = event.params.to;
      ipnft.save();
    }
  }
}

export function handleReadAccess(event: ReadAccessGrantedEvent): void {
  let ipnft = Ipnft.load(event.params.tokenId.toString());
  if (!ipnft) {
    return;
  }

  //read access ids are keccak256(abi.encode(tokenId,address))
  //eg: 1 0x70997970c51812dc3a010c7d01b50e0d17dc79c8
  //keccak(0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8)
  //-> 0x2dcd0246be9dc8135a607e7e3f46bb8a93ebed3ec895527f1ace3477797a0adf
  //in ethers: ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["uint256","address"], [1,"0x70997970c51812dc3a010c7d01b50e0d17dc79c8"]))
  //in solidity: keccak256(abi.encode(tokenId,reader));

  let tupleArray: Array<ethereum.Value> = [
    ethereum.Value.fromUnsignedBigInt(event.params.tokenId),
    ethereum.Value.fromAddress(event.params.reader)
  ];
  //https://thegraph.com/docs/en/release-notes/assemblyscript-migration-guide/#casting
  let tuple = changetype<ethereum.Tuple>(tupleArray);
  let encoded = ethereum.encode(ethereum.Value.fromTuple(tuple));
  if (!encoded) {
    return;
  }

  const canReadId = crypto
    .keccak256(changetype<ByteArray>(encoded))
    .toHexString();

  let canRead = new CanRead(canReadId);
  canRead.ipnft = ipnft.id;
  canRead.reader = event.params.reader;
  canRead.until = event.params.until;

  canRead.save();
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

  store.remove('Reservation', event.params.tokenId.toString());
}

export function handleSymbolUpdated(event: SymbolUpdatedEvent): void {
  let ipnft = Ipnft.load(event.params.tokenId.toString());
  if (ipnft) {
    ipnft.symbol = event.params.symbol;
    ipnft.save();
  }
}

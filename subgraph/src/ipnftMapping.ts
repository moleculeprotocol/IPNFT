import {
  Address,
  BigInt,
  ByteArray,
  crypto,
  ethereum,
  log,
  store
} from '@graphprotocol/graph-ts'
import {
  IPNFT as IPNFTContract,
  IPNFTMinted as IPNFTMintedEvent,
  MetadataUpdate as MetadataUpdateEvent,
  ReadAccessGranted as ReadAccessGrantedEvent,
  Reserved as ReservedEvent,
  Transfer as TransferEvent
} from '../generated/IPNFT/IPNFT'
import { IpnftMetadata as IpnftMetadataTemplate } from '../generated/templates'
import { CanRead, Ipnft, Reservation } from '../generated/schema'

export function handleTransfer(event: TransferEvent): void {
  if (event.params.to == Address.zero()) {
    store.remove('Ipnft', event.params.tokenId.toString())
    return
  }
  if (event.params.from != Address.zero()) {
    let ipnft = Ipnft.load(event.params.tokenId.toString())
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

  //read access ids are keccak256(abi.encode(tokenId,address))
  //eg: 1 0x70997970c51812dc3a010c7d01b50e0d17dc79c8
  //keccak(0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8)
  //-> 0x2dcd0246be9dc8135a607e7e3f46bb8a93ebed3ec895527f1ace3477797a0adf
  //in ethers: ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["uint256","address"], [1,"0x70997970c51812dc3a010c7d01b50e0d17dc79c8"]))
  //in solidity: keccak256(abi.encode(tokenId,reader));

  let tupleArray: Array<ethereum.Value> = [
    ethereum.Value.fromUnsignedBigInt(event.params.tokenId),
    ethereum.Value.fromAddress(event.params.reader)
  ]
  //https://thegraph.com/docs/en/release-notes/assemblyscript-migration-guide/#casting
  let tuple = changetype<ethereum.Tuple>(tupleArray)
  let encoded = ethereum.encode(ethereum.Value.fromTuple(tuple))
  if (!encoded) {
    return
  }

  const canReadId = crypto
    .keccak256(changetype<ByteArray>(encoded))
    .toHexString()

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

function updateIpnftMetadata(ipnft: Ipnft, uri: string, timestamp: BigInt): void {
    let ipfsLocation = uri.replace('ipfs://', '');
    if (!ipfsLocation || ipfsLocation == uri) {
      log.error("Invalid URI format for tokenId {}: {}", [ipnft.id, uri])
      return
    }

    ipnft.tokenURI = uri
    ipnft.metadata = ipfsLocation
    ipnft.updatedAtTimestamp = timestamp
    IpnftMetadataTemplate.create(ipfsLocation)
}

//the underlying parameter arrays are misaligned, hence we cannot cast or unify both events
export function handleMint(event: IPNFTMintedEvent): void {
  let ipnft = new Ipnft(event.params.tokenId.toString())
  ipnft.owner = event.params.owner
  ipnft.createdAt = event.block.timestamp
  ipnft.symbol = event.params.symbol
  updateIpnftMetadata(ipnft, event.params.tokenURI, event.block.timestamp)
  store.remove('Reservation', event.params.tokenId.toString())
  ipnft.save()

}

export function handleMetadataUpdated(event: MetadataUpdateEvent): void {
  let ipnft = Ipnft.load(event.params._tokenId.toString())
  if (!ipnft) {
    log.error('ipnft {} not found', [event.params._tokenId.toString()])
    return
  }

  //erc4906 is not emitting the new url, we must query it ourselves
  let _ipnftContract = IPNFTContract.bind(event.params._event.address);
  let newUri = _ipnftContract.tokenURI(event.params._tokenId)
  if (!newUri || newUri == "") {
    log.debug("no new uri found for token, likely just minted {}", [event.params._tokenId.toString()])
    return 
  }
  updateIpnftMetadata(ipnft, newUri, event.block.timestamp)  
  ipnft.save()
}


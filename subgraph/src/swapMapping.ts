import { Bytes, log, store } from '@graphprotocol/graph-ts'
import { Allowed, Ipnft, Listing } from '../generated/schema'
import {
  AllowlistUpdated as AllowlistUpdatedEvent,
  Listed as ListedEvent,
  Purchased as PurchasedEvent,
  Unlisted as UnlistedEvent
} from '../generated/SchmackoSwap/SchmackoSwap'

export function handleListed(event: ListedEvent): void {
  let ipnft = Ipnft.load(event.params.listing.tokenId.toString())
  if (!ipnft) {
    //todo this happens on tx 955bf2e64f3d8e5ec00ad881a0e977a45105a4bf0dfded33772979128271e271
    //with listing id 3749398527494096271526692317934317558679223690247858923080726539391626332249
    //find out how that is possible...
    log.warning('LISTED: Could not load ipnft by its token id {}.', [
      event.params.listing.tokenId.toString()
    ])
    return
  }

  let listing = new Listing(event.params.listingId.toString())

  listing.ipnft = ipnft.id
  listing.creator = event.params.listing.creator
  listing.tokenAmount = event.params.listing.tokenAmount
  listing.paymentToken = event.params.listing.paymentToken
  listing.askPrice = event.params.listing.askPrice
  listing.beneficiary = event.params.listing.beneficiary
  listing.createdAt = event.block.timestamp

  listing.save()
}

//todo delete this maybe?
export function handleUnlisted(event: UnlistedEvent): void {
  let listing = Listing.load(event.params.listingId.toString())
  if (!listing) {
    log.debug(
      `could not load listing from listingId: ${event.params.listingId.toString()}`,
      []
    )
  } else {
    listing.unlistedAt = event.block.timestamp

    listing.save()
  }
}

export function handleAllowlistUpdated(event: AllowlistUpdatedEvent): void {
  let listing = Listing.load(event.params.listingId.toString())
  if (!listing) {
    log.debug(
      `could not load listing from tokenId: ${event.params.listingId.toString()}`,
      []
    )
    return
  }

  const allowlistId = listing.id + '-' + event.params.buyer.toHexString()

  let allowed = Allowed.load(allowlistId)
  if (allowed) {
    if (event.params._isAllowed === false) {
      store.remove('Allowed', allowlistId)
      return
    }
  } else {
    if (event.params._isAllowed === false) {
      return
    }
    allowed = new Allowed(allowlistId)
  }

  allowed.account = event.params.buyer
  allowed.listing = listing.id
  allowed.allowed = event.params._isAllowed

  allowed.save()
}

export function handlePurchased(event: PurchasedEvent): void {
  let listing = Listing.load(event.params.listingId.toString())
  if (!listing) {
    log.debug(
      `could not load listing from listingId: ${event.params.listingId.toString()}`,
      []
    )
    return
  }

  listing.purchasedAt = event.block.timestamp
  listing.buyer = event.params.buyer
  listing.save()
}

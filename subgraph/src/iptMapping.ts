import { Address, BigInt, log } from '@graphprotocol/graph-ts'
import { IPT, IPTBalance } from '../generated/schema'
import { Transfer as TransferEvent, Capped as CappedEvent } from '../generated/templates/IPToken/IPToken'

function createOrUpdateBalances(
  owner: Address,
  address: string,
  value: BigInt
): void {
  let balanceId = address + '-' + owner.toHexString()
  let balance = IPTBalance.load(balanceId)
  if (!balance) {
    balance = new IPTBalance(balanceId)
    balance.ipt = address
    balance.balance = value
    balance.owner = owner
    balance.agreementSignature = null
  } else {
    balance.balance = balance.balance.plus(value)
  }
  balance.save()
}

export function handleCapped(event: CappedEvent): void {
  let ipt = IPT.load(event.address.toHexString())
  if (!ipt) {
    log.error('[IPT] Ipnft not found for id: {}', [event.address.toHexString()])
    return
  }
  ipt.capped = true
  ipt.save()
}

export function handleTransfer(event: TransferEvent): void {
  let from = event.params.from
  let to = event.params.to
  let value = event.params.value

  let ipt = IPT.load(event.address.toHexString())
  if (!ipt) {
    log.error('[IPT] Ipnft not found for id: {}', [event.address.toHexString()])
    return
  }

  //mint
  if (from == Address.zero()) {
    createOrUpdateBalances(to, event.address.toHexString(), value)
    ipt.totalIssued = ipt.totalIssued.plus(value)
    ipt.circulatingSupply = ipt.circulatingSupply.plus(value)
    ipt.save()

    return
  }

  //burn
  if (to == Address.zero()) {
    createOrUpdateBalances(from, event.address.toHexString(), value.neg())
    ipt.circulatingSupply = ipt.circulatingSupply.minus(value)
    ipt.save()
    return
  }

  //transfer
  createOrUpdateBalances(from, event.address.toHexString(), value.neg())
  createOrUpdateBalances(to, event.address.toHexString(), value)
}

// export function handleSharesClaimed(event: SharesClaimedEvent): void {
//   let reactedIpnft = ReactedIpnft.load(event.params.moleculesId.toString());
//   if (!reactedIpnft) {
//     log.error('ReactedIpnft ipnft not found for id: {}', [
//       event.params.moleculesId.toString()
//     ]);
//     return;
//   }
//   reactedIpnft.claimedShares = reactedIpnft.claimedShares.plus(
//     event.params.amount
//   );
//   reactedIpnft.save();
// }

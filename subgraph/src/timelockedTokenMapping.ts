import { dataSource, log, BigInt } from '@graphprotocol/graph-ts'

import { LockedSchedule, Molecule } from '../generated/schema'
import {
  ScheduleCreated,
  ScheduleReleased
} from '../generated/templates/TimelockedToken/TimelockedToken'

export function handleScheduled(event: ScheduleCreated): void {
  let context = dataSource.context()
  let schedule = new LockedSchedule(event.params.scheduleId)

  let reactedIpnft = context.getBytes('reactedIpnft').toHexString()
  let moleculesId = reactedIpnft + '-' + event.params.beneficiary.toHexString()

  let molecule = Molecule.load(moleculesId)
  if (!molecule) {
    molecule = new Molecule(moleculesId)
    molecule.reactedIpnft = reactedIpnft
    molecule.balance = BigInt.fromI32(0)
    molecule.owner = event.params.beneficiary
    molecule.agreementSignature = null
    molecule.save()
  }

  schedule.molecule = moleculesId
  schedule.tokenContract = context.getBytes('lockingContract')
  schedule.beneficiary = event.params.beneficiary
  schedule.amount = event.params.amount
  schedule.expiresAt = event.params.expiresAt
  schedule.claimedAt = null

  schedule.save()
}

export function handleReleased(event: ScheduleReleased): void {
  let schedule = LockedSchedule.load(event.params.scheduleId)
  if (!schedule) {
    log.warning('schedule {} not found', [
      event.params.scheduleId.toHexString()
    ])
    return
  }

  schedule.claimedAt = event.block.timestamp
  schedule.save()
}

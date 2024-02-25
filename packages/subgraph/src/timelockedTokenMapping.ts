import { dataSource, log, BigInt } from '@graphprotocol/graph-ts'

import { LockedSchedule, Balance } from '../generated/schema'
import {
  ScheduleCreated,
  ScheduleReleased
} from '../generated/templates/TimelockedToken/TimelockedToken'

export function handleScheduled(event: ScheduleCreated): void {
  let context = dataSource.context()
  let schedule = new LockedSchedule(event.params.scheduleId)

  let token = context.getBytes('token')
  let balanceId = token.toHexString() + '-' + event.params.beneficiary.toHexString()

  let balance = Balance.load(balanceId)
  if (!balance) {
    balance = new Balance(balanceId)
    balance.token = token
    balance.balance = BigInt.fromI32(0)
    balance.owner = event.params.beneficiary
    balance.agreementSignature = null
    balance.save()
  }

  schedule.balance = balanceId
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

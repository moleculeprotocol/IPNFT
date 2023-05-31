import { dataSource, log } from '@graphprotocol/graph-ts'

import { LockedSchedule } from '../generated/schema'
import {
  ScheduleCreated,
  ScheduleReleased
} from '../generated/templates/TimelockedToken/TimelockedToken'

export function handleScheduled(event: ScheduleCreated): void {
  let context = dataSource.context()
  let schedule = new LockedSchedule(event.params.scheduleId)
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

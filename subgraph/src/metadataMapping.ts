import { json, Bytes, dataSource } from '@graphprotocol/graph-ts'
import { IpnftMetadata } from '../generated/schema'

export function handleMetadata(content: Bytes): void {
  let ipnftMetadata = new IpnftMetadata(dataSource.stringParam())
  const value = json.fromBytes(content).toObject()
  if (value) {
    const image = value.get('image')
    const name = value.get('name')
    const description = value.get('description')
    const externalURL = value.get('external_url')

    if (name && image && description && externalURL) {
      ipnftMetadata.name = name.toString()
      ipnftMetadata.image = image.toString()
      ipnftMetadata.externalURL = externalURL.toString()
      ipnftMetadata.description = description.toString()
    }

    ipnftMetadata.save()
  }
}
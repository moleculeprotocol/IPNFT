import { json, Bytes, dataSource,  } from '@graphprotocol/graph-ts'
import { IpnftMetadata, IpnftProjectDetails } from '../generated/schema'

export function handleMetadata(content: Bytes): void {
  const value = json.fromBytes(content).toObject()
  if (value) {
    const image = value.get('image')
    const name = value.get('name')
    const description = value.get('description')
    const externalURL = value.get('external_url')
    
    if (name && image && description && externalURL) {
      let ipnftMetadata = new IpnftMetadata(dataSource.stringParam())
      ipnftMetadata.name = name.toString()
      ipnftMetadata.image = image.toString()
      ipnftMetadata.externalURL = externalURL.toString()
      ipnftMetadata.description = description.toString()
  
   
      const _properties = value.get('properties')
      if (_properties) {
        const properties = _properties.toObject()
        const initial_symbol = properties.get('initial_symbol')
        if (initial_symbol) {
          ipnftMetadata.initialSymbol = initial_symbol.toString()
        }

        let details = new IpnftProjectDetails("pd-"+ dataSource.stringParam())
        const _project_details = properties.get('project_details')

        if (_project_details) {
          let projectDetails = _project_details.toObject()

          let _organization = projectDetails.get('organization')
          if (_organization) {
            details.organization = _organization.toString()
          }

          let _topic = projectDetails.get('topic')
          if (_topic) {
            details.topic = _topic.toString()
          }

          let _research_lead = projectDetails.get('research_lead')

          if (_research_lead) {
            let researchLead = _research_lead.toObject()
            let researchLead_email = researchLead.get('email')
            let researchLead_name = researchLead.get('name')
            
            if (researchLead_email && researchLead_name) {
              details.researchLead_email = researchLead_email.toString()
              details.researchLead_name = researchLead_name.toString()
            }
          }

          let _funding_amount = properties.get('funding_amount')
          if (_funding_amount) {
            let funding_amount = _funding_amount.toObject()
            let _fundingAmount_value = funding_amount.get('value')
            let _fundingAmount_decimals = funding_amount.get('decimals')
            let _fundingAmount_currency = funding_amount.get('currency')
            let _fundingAmount_currencyType = funding_amount.get('currency_type')
            
            if (_fundingAmount_value && _fundingAmount_decimals && _fundingAmount_currency && _fundingAmount_currencyType) {
              details.fundingAmount_value = i32(_fundingAmount_value.toI64())
              details.fundingAmount_decimals = i8(_fundingAmount_decimals.toI64())
              details.fundingAmount_currency = _fundingAmount_currency.toString()
              details.fundingAmount_currencyType = _fundingAmount_currencyType.toString()
            }
          }
        }
        details.save()
        ipnftMetadata.projectDetails = details.id
      }

      ipnftMetadata.save()
    }

  }
}
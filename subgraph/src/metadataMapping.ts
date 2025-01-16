import { json, Bytes, dataSource, log  } from '@graphprotocol/graph-ts'
import { IpnftMetadata } from '../generated/schema'

export function handleMetadata(content: Bytes): void {
  const value = json.fromBytes(content).toObject()
  if (value) {
    const image = value.get('image')
    const name = value.get('name')
    const description = value.get('description')
    const externalURL = value.get('external_url')
    
    let ipnftMetadata = new IpnftMetadata(dataSource.stringParam())
    
    if (name && image && description && externalURL) {
      ipnftMetadata.name = name.toString()
      ipnftMetadata.image = image.toString()
      ipnftMetadata.externalURL = externalURL.toString()
      ipnftMetadata.description = description.toString()
  
      ipnftMetadata.save()
    } else {
      log.info("[handlemetadata] name, image, description, external_url not found", [])
    }

    let _properties = value.get('properties')
    if (_properties) {
      let properties = _properties.toObject()
      let _initial_symbol = properties.get('initial_symbol')
      if (_initial_symbol) {
        ipnftMetadata.initialSymbol = _initial_symbol.toString()
      } else {
        ipnftMetadata.initialSymbol = ""
        log.info("[handlemetadata] initial_symbol not found", [])
      }

      let _project_details = properties.get('project_details')

      if (_project_details) {
        let projectDetails = _project_details.toObject()

        let _organization = projectDetails.get('organization')
        if (_organization) {
          ipnftMetadata.organization = _organization.toString()
        }

        let _topic = projectDetails.get('topic')
        if (_topic) {
          ipnftMetadata.topic = _topic.toString()
        }

        let _research_lead = projectDetails.get('research_lead')

        if (_research_lead) {
          let researchLead = _research_lead.toObject()
          let researchLead_email = researchLead.get('email')
          let researchLead_name = researchLead.get('name')
          
          if (researchLead_email && researchLead_name) {
            ipnftMetadata.researchLead_email = researchLead_email.toString()
            ipnftMetadata.researchLead_name = researchLead_name.toString()
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
            // on json metadata this can be a decimal value. I'm using a string to store as there's imo no f64 compatible decimal type on the schema scalar types
            // https://thegraph.com/docs/en/subgraphs/developing/creating/ql-schema/#built-in-scalar-types
            ipnftMetadata.fundingAmount_value = _fundingAmount_value.toF64().toString()
            ipnftMetadata.fundingAmount_decimals = i8(_fundingAmount_decimals.toI64())
            ipnftMetadata.fundingAmount_currency = _fundingAmount_currency.toString()
            ipnftMetadata.fundingAmount_currencyType = _fundingAmount_currencyType.toString()
          }
        }
      }      
    }
    ipnftMetadata.save()
  }
}
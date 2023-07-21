#!/bin/sh

# https://docs.ipfs.tech/install/run-ipfs-inside-docker/#customizing-your-node

set -ex

ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["GET", "POST"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Headers '["Authorization"]'
ipfs config --json API.HTTPHeaders.Access-Control-Expose-Headers '["Location"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Credentials '["true"]'

ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Methods '["GET", "POST"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Headers '["Authorization"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Expose-Headers '["Location"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Credentials '["true"]'

# https://web3.storage/docs/reference/peering/
# allows us to also pull w3s content from our local machine
ipfs config --json Peering.Peers '[{"ID": "bafzbeibhqavlasjc7dvbiopygwncnrtvjd2xmryk5laib7zyjor6kf3avm","Addrs": ["/dnsaddr/elastic.dag.house"]}]'

#https://github.com/ipfs/kubo/blob/master/docs/config.md#implicit-defaults-of-gatewaypublicgateways
#axios is confused with local ipfs subdomains
ipfs config --json Gateway.PublicGateways '{"localhost":{"Paths": ["/ipfs", "/ipns"],"UseSubdomains":false}}'

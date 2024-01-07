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
# allows us to also pull w3s / pinata content from our local machine
ipfs config --json Peering.Peers '[{"ID": "bafzbeibhqavlasjc7dvbiopygwncnrtvjd2xmryk5laib7zyjor6kf3avm","Addrs": ["/dnsaddr/elastic.dag.house"]}]'
ipfs config --json Peering.Peers '[{"ID": "QmWaik1eJcGHq1ybTWe7sezRfqKNcDRNkeBaLnGwQJz1Cj","Addrs": ["/dnsaddr/fra1-1.hostnodes.pinata.cloud"]}]'
ipfs config --json Peering.Peers '[{"ID": "QmNfpLrQQZr5Ns9FAJKpyzgnDL2GgC6xBug1yUZozKFgu4","Addrs": ["/dnsaddr/fra1-2.hostnodes.pinata.cloud"]}]'
ipfs config --json Peering.Peers '[{"ID": "QmPo1ygpngghu5it8u4Mr3ym6SEU2Wp2wA66Z91Y1S1g29","Addrs": ["/dnsaddr/fra1-3.hostnodes.pinata.cloud"]}]'
ipfs config --json Peering.Peers '[{"ID": "QmRjLSisUCHVpFa5ELVvX3qVPfdxajxWJEHs9kN3EcxAW6","Addrs": ["/dnsaddr/nyc1-1.hostnodes.pinata.cloud"]}]'
ipfs config --json Peering.Peers '[{"ID": "QmPySsdmbczdZYBpbi2oq2WMJ8ErbfxtkG8Mo192UHkfGP","Addrs": ["/dnsaddr/nyc1-2.hostnodes.pinata.cloud"]}]'
ipfs config --json Peering.Peers '[{"ID": "QmSarArpxemsPESa6FNkmuu9iSE1QWqPX2R3Aw6f5jq4D5","Addrs": ["/dnsaddr/nyc1-3.hostnodes.pinata.cloud"]}]'


#https://github.com/ipfs/kubo/blob/master/docs/config.md#implicit-defaults-of-gatewaypublicgateways
#axios is confused with local ipfs subdomains
ipfs config --json Gateway.PublicGateways '{"localhost":{"Paths": ["/ipfs", "/ipns"],"UseSubdomains":false}}'

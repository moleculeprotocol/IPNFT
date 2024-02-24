#!/bin/bash

find . -type f -exec basename {} \; > all.cid.text

while IFS= read -r line; do
    echo "$line"
    ipfs dht provide "$line"
    ipfs pin remote add --service=pinata "$line"
done < all.cid.text
# How to run subgraph and contracts locally

1. Startup local anvil node
   1. Run `anvil` in a terminal window and keep it running.

2. Deploy IP-NFT Contract to a local anvil node
   1. Go to IP-NFT Contract folder
   2. Take one of the private keys you get and insert them into the `.env` file at `PRIVATE_KEY`.
   3. Run `source .env` to get the ENV variables into your current terminal session.
   4. Run `forge script script/IPNFT.s.sol:IPNFTScript --fork-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv` to deploy the contract to your local `anvil` node.
   5. Contract should be deployed at: `0x5fbdb2315678afecb367f032d93f642f64180aa3`

3. Deploy SimpleOpenSea Contract to a local anvil node
   1. Go to SimpleOpenSea Contract folder
   2. Take one of the private keys you get and insert them into the `.env` file at `PRIVATE_KEY`.
   3. Run `source .env` to get the ENV variables into your current terminal session.
   4. Run `forge script script/SimpleOpenSea.s.sol:SimpleOpenSeaScript --fork-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv` to deploy the contract to your local `anvil` node.
   5. Contract should be deployed at: `0xe7f1725e7734ce288f8367e1bb143e90bb3f0512`

4. Deploy ERC-20 Contract to a local anvil node
   1. Go to ERC-20 Contract folder
   2. Take one of the private keys you get and insert them into the `.env` file at `PRIVATE_KEY`.
   3. Run `source .env` to get the ENV variables into your current terminal session.
   4. Run `forge script script/MyToken.s.sol:MyTokenScript --fork-url $ANVIL_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv` to deploy the contract to your local `anvil` node.
   5. Contract should be deployed at: `0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0`

5. Create a Reservation, Update the reservationURI, mint an IP-NFT and set Approval for SimpleOpenSea Contract
   1. Run `cast send -i 0x5fbdb2315678afecb367f032d93f642f64180aa3 "reserve()(uint256)" --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil
   2. Run `cast send -i 0x5fbdb2315678afecb367f032d93f642f64180aa3 "updateReservationURI(uint256, string calldata)()" 0 "teststring" --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil
   3. Run `cast send -i 0x5fbdb2315678afecb367f032d93f642f64180aa3 "mintReservation(address, uint256)(uint256)" 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 0 --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` -- account (0) from anvil
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil
   4. Run `cast send -i 0x5fbdb2315678afecb367f032d93f642f64180aa3 "approve(address, uint256)()" 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 0 --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil

6. Create a Listing, cancel a Listing
   1. Run `cast send -i 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 "list(address, uint256, address, uint256)(uint256)" 0x5fbdb2315678afecb367f032d93f642f64180aa3 0 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 10 --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil
   2. Run `cast send -i 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 "cancel(uint256)() TODO: Add listingId (will always be the same as its a keccak hash)" --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil

7. Create a new Listing, add Account(1) to whitelist, supply Account (1) with ERC20, increase Allowance, fullfill listing
   1. Run `cast send -i 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 "list(address, uint256, address, uint256)(uint256)" 0x5fbdb2315678afecb367f032d93f642f64180aa3 0 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 10 --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil
   2. Run `cast send -i 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 "changeBuyerAllowance(uint256, address, bool)()" TODO: Add listingId 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 true --from 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`
      1. Enter as private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` -- account (0) from anvil
   3. Run `cast send -i 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 "mint(address, uint256)()" 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 10 --from 0x70997970c51812dc3a010c7d01b50e0d17dc79c8`
      1. Enter as private key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` -- account (1) from anvil
   4. Run `cast send -i 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0 "increaseAllowance(address, uint256)()" 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 10 --from 0x70997970c51812dc3a010c7d01b50e0d17dc79c8`
      1. Enter as private key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` -- account (1) from anvil
   5. Run `cast send -i 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 "fulfill(uint256)()" TODO: Add listingId --from 0x70997970c51812dc3a010c7d01b50e0d17dc79c8`
      1. Enter as private key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` -- account (1) from anvil

8. Startup docker container

    ```sh
    docker compose up
    ```

9. Prepare subgraph for local build, create and deploy
   This creates the subgraph.yaml file with the correct contract address the contract will be deployed to on your local anvil chain

    ```sh
    yarn prepare:local
    yar build
    yarn create-local
    yarn deploy-local
    ```

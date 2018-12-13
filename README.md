# discordtipbot

[![Build Status](https://travis-ci.org/greenbigfrog/discordtipbot.svg?branch=master)](https://travis-ci.org/greenbigfrog/discordtipbot)

Highly configurable tip bot for the chat plattform discord. **DO NOT RUN THIS CODE UNLESS YOU KNOW WHAT YOU ARE DOING!**

Instead of executing this code yourself, feel free to contact me at https://discord.gg/r3NspwB to discuss me hosting it for you.

If you collect some kind of bounty or donation(s), I'd appreciate you forwarding some of it after your hosting costs.

## Terms

In no event shall this bot or it's dev be responsible in the event of lost, stolen or misdirected funds.

## About
- First we launch the main watcher at src/discordtipbot.cr
- This reads the config file
- It then launches a fiber for each bot

## Dependencies
- docker

## Initial setup
<!--
- Install core wallet for each currency you plan on running
- Add the RPC info to each wallets corresponding config file (`rpcuser` and `rpcpassword`)
- Add `walletnotify=curl --retry 10 -X POST http://127.0.0.1:ABC/?tx=%s` to your wallets config file, replacing `ABC` with the walletnotify port you plan on using
- It's recommendable to run your node as a full node, but to limit the connections to ~30, since else you might run into performance issues (`maxconnections=30`)
-->

- Create a overlay network: `docker network create -d overlay --attachable dtb`
- Clone and cd into this repository: `git clone https://github.com/greenbigfrog/discordtipbot.git`
- Create a directory which will contain all the tipbot related stuff: `mkdir tipbot`
- Copy and edit `sample-config.json` into `tipbot`
- Modify `scripts/postgres-init.sh` to reflect the various coins, which will both create the required databases, as well as initialize a empty schema
- Launch watchtower to automatically watch for changes to the images (in usual build process made by Travis): `docker run -d --name watchtower --network dtb -v /var/run/docker.sock:/var/run/docker.sock v2tec/watchtower`
- Start a docker container called `database`, which'll mount a folder called `postgres-data` in the local directory: `docker run -d --name database --network dtb -v $PWD/postgres-data:/var/lib/postgresql/data -v $PWD/../sql/schema.sql:/schema.sql -v $PWD/../scripts/postgres-init.sh:/docker-entrypoint-initdb.d/postgres-init.sh -d postgres:11.1-alpine`

## Building
`scripts/deploy_to_docker.bash` contains instructions to build both a `dtb-launcher` and `dtb-website` image which will then contain binaries.

## Running
- Make sure you are in the directory with the config file and postgres data
- Database: `docker run -d --name database --network dtb -v $PWD/postgres-data:/var/lib/postgresql/data postgres:11.1-alpine`
- TipBot: `docker run -d --name discordbot --network dtb -v $PWD/config.json:/config.json greenbigfrog/dtb-launcher:latest`
- Website: `docker run -d --name website --network dtb -v $PWD/config.json:/config.json greenbigfrog/dtb-website:latest`
- Wallet: `docker run -d --name dogecoind --network dtb -v ~/.dogecoin/:/dogecoin/.dogecoin/ greenbigfrog/dogecoin -printtoconsole`

- cli: `docker run --rm -ti --network dtb -v ~/.dogecoin/:/dogecoin/.dogecoin/ greenbigfrog/dogecoin dogecoin-cli -rpcconnect=dogecoind -rpcuser=a -rpcpassword=b getinfo`
- psql: `docker run --rm -ti --network dtb postgres:11.1-alpine psql -h database -U docker dogecoin`

## Development

Preferably run your wallets in testnet mode by adding `testnet=1` to each wallets config file during development

## Contributing

1. Fork it ( https://github.com/greenbigfrog/discordtipbot/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [greenbigfrog](https://github.com/greenbigfrog) Jonathan B. - creator, maintainer
- [z64](https://github.com/z64) Zac Nowicki - advisor, reviewer

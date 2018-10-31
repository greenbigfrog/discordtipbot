# discordtipbot

Highly configurable tip bot for the chat plattform discord. **DO NOT RUN THIS CODE UNLESS YOU KNOW WHAT YOU ARE DOING!**

## Terms

In no event shall this bot or it's dev be responsible in the event of lost, stolen or misdirected funds.

## About
- First we launch the main watcher at src/discordtipbot.cr
- This reads the config file
- It then launches a fiber for each bot

## Dependencies
- crystal
- postgresql
- wallets as you wish

## Installation

- First make sure you've got [crystal](https://crystal-lang.org/) installed.
- clone the repo
- Install shards (`shards install`)
- Install core wallet for each currency you plan on running
- Add the RPC info to each wallets corresponding config file (`rpcuser` and `rpcpassword`)
- Add `walletnotify=curl -X POST http://127.0.0.1:ABC/?tx=%s` to your wallets config file, replacing `ABC` with the walletnotify port you plan on using
- It's recommendable to run your node as a full node, but to limit the connections to ~30, since else you might run into performance issues (`maxconnections=30`)
- Create the database for each of the currencies you plan on running on: `createdb dogecoin-testnet`
- Set the schema for the database by running: `psql -d dogecoin-testnet -f schema.sql`
- Copy the sample config and edit it
- Run bots using `crystal run src/discordtipbot.cr -- config.json`

## Development

Preferably run your wallets in testnet mode by adding `testnet=1` to each wallets config file during development

## Contributing

1. Fork it ( https://github.com/trethiest/discordtipbot/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [greenbigfrog](https://github.com/greenbigfrog) Jonathan B. - creator
- [z64](https://github.com/z64) Zac Nowicki - advisor, reviewer
- [incognitojam](https://github.com/incognitojam) Cameron Clough - contributor

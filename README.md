# discordtipbot

TODO: Write a description here

## About
- First we launch the main watcher at src/discordtipbot.cr
- This reads the config file
- It then forks a process for each bot
- And in every of those processes it then launches src/discordtipbot/controller.cr which creates the actual tipbot

## Installation

- First make sure you've got [crystal](https://crystal-lang.org/) installed.
- Install dependencies (`shards install`)
- TODO: wallet setup
- create the database for each of the currencies you plan on running on: `createdb dogecoin-testnet`
- set the schema for the database by running: `psql -d dogecoin-testnet' -f schema.sql'`
- Copy the sample config
- Run bot `crystal run src/discordtipbot.cr -- config.json`

## Usage

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/greenbigfrog/discordtipbot/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [greenbigfrog](https://github.com/greenbigfrog) Jonathan B. - creator, maintainer

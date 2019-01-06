require "raven"
require "logger"
require "pg"
require "pg/pg_ext/big_decimal"
require "discordcr"
require "big"
require "big/json"
require "discordcr-middleware"

require "../data/**"

require "../common/amount"
require "../common/coin_api"
require "../common/raven_spawn"

require "./**"

class DiscordTipBot
  def self.run
    abort "No Config File specified! Exiting!" if ARGV.size == 0

    log = Logger.new(STDOUT)

    log.debug("Attempting to load config from #{ARGV[0].inspect}")
    Config.load(ARGV[0])
    log.info("Loaded config from #{ARGV[0].inspect}")

    Raven.configure do |raven_config|
      raven_config.async = true
    end

    Raven.capture do
      # Set your log level here
      log.level = Logger::DEBUG

      log.debug("Tipbot network getting started")

      shared_cache = Discord::Cache.new(Discord::Client.new(""))

      log.debug("starting forking")
      Config.current.each do |name, config|
        raven_spawn(name: "#{name} Bot") do
          bot = Discord::Client.new(config.discord_token)
          cache = Discord::Cache.new(bot)
          shared_cache.bind(cache)
          bot.cache = cache

          DiscordBot.new(bot, cache, config, log).run
        end
      end
      log.debug("finished forking")

      log.info("All bots should be running now")
    end
    sleep
  end
end

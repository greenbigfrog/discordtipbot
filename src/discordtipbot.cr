require "raven"
require "raven/integrations/kernel/spawn"
require "logger"
require "pg"
require "pg/pg_ext/big_decimal"
require "discordcr"
require "big"
require "big/json"

require "./discordtipbot/*"

unless ENV["TIPBOT_ENV"]? == "test"
  puts "No Config File specified! Exiting!" if ARGV.size == 0
  exit if ARGV.size == 0

  Raven.configure do |config|
    config.async = true
  end

  Raven.capture do
    log = Logger.new(STDOUT)

    # Set your logger level here
    log.level = Logger::DEBUG

    log.debug("Tipbot network getting started")

    log.debug("Attempting to read config from \"#{ARGV[0]}\"")
    config = File.open(ARGV[0], "r") do |file|
      Array(Config).from_json(file)
    end
    log.info("read config from \"#{ARGV[0]}\"")

    log.debug("starting forking")
    bots = config.each do |x|
      raven_spawn(name: "#{x.coinname_full} Bot") do
        Controller.new(x, log)
      end
    end
    log.debug("finished forking")

    log.info("All bots should be running now")
  end
  sleep
end

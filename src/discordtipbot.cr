require "logger"
require "pg"
require "pg/pg_ext/big_decimal"
require "discordcr"
require "big"
require "big/json"

require "./discordtipbot/*"

unless ENV["TIPBOT_ENV"]? == "test"
  puts "No config file specified! Exiting!" if ARGV.size == 0
  exit if ARGV.size == 0

  log = Logger.new(STDOUT)
  log.level = Logger::DEBUG

  log.debug("Tipbot network getting started")

  log.debug("Attempting to read global config from \"#{ARGV[0]}\"")
  global_config = File.open(ARGV[0], "r") do |file|
    GlobalConfig.from_json(file)
  end
  log.info("Read global config from \"#{ARGV[0]}\"")
  
  log.info("Setting log level to " + global_config.log_level.to_s)
  log.level = global_config.log_level

  log.debug("Starting forking")
  bots = global_config.bots.each do |config|
    spawn do
      Controller.new(config, log)
    end
  end
  log.debug("Finished forking")

  log.info("All bots should be running now")
  sleep
end

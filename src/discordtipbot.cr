require "./discordtipbot/*"

require "logger"
require "pg"
require "discordcr"

log = Logger.new(STDOUT)

# Set your logger level here
log.level = Logger::DEBUG

log.debug("Tipbot network got started")

log.debug("Attempting to read config from \"#{ARGV[0]}\"")
config = File.open(ARGV[0], "r") do |file|
  Array(Config).from_json(file)
end
log.info("read config from \"#{ARGV[0]}\"")

log.debug("starting forking")
bots = config.each { |x| Process.fork { Controller.new(x, log) } }
log.debug("finished forking")

log.info("All bots should be running now")

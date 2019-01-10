require "./twitch/twitchtipbot"

require "../data/balance"
require "../data/account"
require "../data/twitch_channel"

require "./twitch/config"

raise "Please specify a valid Config file" unless ARGV[0]?

require "./common/constants"

# TODO improve this
LOG  = Logger.new(STDOUT)
DATA = PG.connect(ENV["POSTGRES"]? || POSTGRES)

config = File.open(ARGV[0], "r") do |file|
  Config.from_json(file)
end

bot = TwitchTipBot.new(config)

bot.start

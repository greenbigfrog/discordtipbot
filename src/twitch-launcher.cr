require "./twitch/twitchtipbot"

require "./common/constants"

# TODO improve this
LOG  = Logger.new(STDOUT)
DATA = PG.connect(ENV["POSTGRES"]? || POSTGRES)

TwitchTipBot.run

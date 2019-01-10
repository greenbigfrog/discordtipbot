require "./discord/discordtipbot"
require "./common/constants"

# TODO improve this
LOG  = Logger.new(STDOUT)
DATA = PG.connect(ENV["POSTGRES"]? || POSTGRES)

DiscordTipBot.run

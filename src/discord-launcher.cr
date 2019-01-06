require "./discord/discordtipbot"

# TODO improve this
LOG  = Logger.new(STDOUT)
DATA = PG.connect("postgresql://frog@localhost:5432/new")

DiscordTipBot.run

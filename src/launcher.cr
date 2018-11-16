require "raven"
require "logger"
require "pg"
require "pg/pg_ext/big_decimal"
require "discordcr"
require "big"
require "big/json"

require "./discordtipbot"
require "./discordtipbot/**"

unless ENV["TIPBOT_ENV"]? == "test"
  DiscordTipBot.new
end

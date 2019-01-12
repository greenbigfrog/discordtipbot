require "pg"
require "pg/pg_ext/big_decimal"

require "big"
require "big/json"

require "raven"

require "../data/**"
require "../common/**"

require "./bot"

class TwitchTipBot
  def self.run
    Raven.configure do |raven_config|
      raven_config.async = true
    end

    Raven.capture do
      Data::Coin.read.each do |coin|
        raven_spawn(name: "#{coin.name_short} Bot") do
          chat_password = coin.twitch_chat_password
          oauth_token = coin.twitch_oauth_token
          oauth_id = coin.twitch_oauth_id
          raise "Missing a Twitch related config value" unless chat_password && oauth_token && oauth_id

          TwitchBot.new(coin).start
        end
      end
    end

    sleep
  end
end

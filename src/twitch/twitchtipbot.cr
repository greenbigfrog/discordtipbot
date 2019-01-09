require "pg"
require "pg/pg_ext/big_decimal"

require "big"
require "big/json"

require "../common/**"

require "./**"

class TwitchTipBot
  @db : DB::Database

  def initialize(@config : Config)
    @db = DB.open(@config.database_url + "?max_pool_size=10")
    @twitch = Twitch::Client.new(@config.oauth_token, @config.oauth_id)
    @coin = CoinApi.new(config, Logger.new(STDOUT))
  end

  def start
    spawn do
      begin
        ChatBot.start(@config, @twitch, @coin)
      rescue e
        puts e
        sleep 1
      end
    end

    spawn do
      ChatBot.start_listening(@config, @coin)
    end

    spawn do
      ChatBot.insert_history_deposits(@coin)
    end

    spawn do
      sleep 5
      loop do
        ChatBot.check_pending_deposits(@coin, @config, @twitch)
        ChatBot.process_pending_withdrawals(@coin)
        sleep 30
      end
    end

    # Block from exiting
    sleep
  end
end

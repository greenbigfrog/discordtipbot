require "./**"

require "mosquito"
require "../../jobs/withdraw"

class TwitchBot
  def initialize(@coin : Data::Coin)
    oauth_token = coin.twitch_oauth_token
    oauth_id = coin.twitch_oauth_id
    raise "Missing oauth token or ID" unless oauth_id && oauth_token
    @twitch = Twitch::Client.new(oauth_token, oauth_id)
    # @coin = CoinApi.new(config, Logger.new(STDOUT))
  end

  def start
    raven_spawn do
      begin
        ChatBot.start(@twitch, @coin)
      rescue ex
        Raven.capture(ex)
        puts ex
        sleep 1
      end
    end

    spawn do
      # ChatBot.start_listening(@coin)
    end

    # spawn do
    #   ChatBot.insert_history_deposits(@coin)
    # end

    # spawn do
    #   sleep 5
    #   loop do
    #     ChatBot.check_pending_deposits(@coin, @config, @twitch)
    #     ChatBot.process_pending_withdrawals(@coin)
    #     sleep 30
    #   end
    # end
  end
end

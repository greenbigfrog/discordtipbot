require "crirc"

PRIVWHISP  = ["PRIVMSG", "WHISPER"]
NO_USER_ID = Exception.new("There was no user_id sent")
NO_ROOM_ID = Exception.new("No Room ID was specified")

module ChatBot
  def start(twitch : Twitch::Client, coin : TB::Data::Coin)
    raise "Missing twitch chat password" unless pass = coin.twitch_chat_password
    client = Crirc::Network::Client.new(
      ip: "irc.chat.twitch.tv",
      port: 6667,
      ssl: false,
      nick: "greenbigfrog",
      pass: pass,
      limiter: RateLimiter(String).new)

    client.connect

    active_users_cache = ActivityCache.new(10.minutes)

    prefix = coin.prefix
    client.start do |bot|
      Plugins::Ping.bind(bot, prefix)
      Plugins::Channels.bind(bot, prefix, twitch, coin)
      Plugins::Balance.bind(bot, coin)
      Plugins::Tip.bind(bot, coin, twitch)
      Plugins::Withdraw.bind(bot, coin)
      Plugins::Deposit.bind(bot, coin)
      Plugins::Support.bind(bot, coin)
      Plugins::Donation.bind(bot, coin)
      Plugins::Whisper.bind(bot)
      Plugins::Rain.bind(bot, coin, twitch, active_users_cache)

      # bot.join(Crirc::Protocol::Chan.new("#monstercat"))

      bot.on_ready do
        # Request Various Twitch specific capabilities.
        # Not checking for acknowledgement on purpose.

        # List of capabilities:
        capabilities = Set{"membership", "tags", "commands"}

        capabilities.each do |capability|
          bot.puts("CAP REQ :twitch.tv/#{capability}")
        end

        # Join all channels that were stored in database during last run
        TB::Data::TwitchChannel.read_names.each do |channel|
          bot.join(Crirc::Protocol::Chan.new("##{channel}"))
        end
      end

      loop do
        begin
          m = bot.gets
          break if m.nil?

          puts "[#{Time.now}] #{m}"
          spawn { bot.handle(m.as(String)) }
        rescue IO::Timeout
        end
      end
    end

    sleep
  end

  extend self

  # Inserts potential deposits during downtime of walletnotify
  def insert_history_deposits(coin : CoinApi)
    txlist = coin.list_transactions(1000).as_a
    return unless txlist.is_a?(Array(JSON::Any))
    return if txlist.empty?

    txlist.each do |tx|
      tx = tx.as_h
      next unless tx.is_a?(Hash(String, JSON::Any))

      next unless tx["category"] == "receive"

      # TODO
      # db.create_coin_transaction(tx["txid"].to_s)
    end
  end

  # :nodoc:
  def extract_nick(address : String)
    address.split('!')[0]
  end

  def mention(login : String, string : String)
    "@#{login} #{string}"
  end
end

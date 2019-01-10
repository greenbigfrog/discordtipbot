require "crirc"

PRIVWHISP  = ["PRIVMSG", "WHISPER"]
NO_USER_ID = Exception.new("There was no user_id sent")
NO_ROOM_ID = Exception.new("No Room ID was specified")

module ChatBot
  def start(config : Config, twitch : Twitch::Client, coin : CoinApi)
    client = Crirc::Network::Client.new(
      ip: "irc.chat.twitch.tv",
      port: 6667,
      ssl: false,
      nick: "greenbigfrog",
      pass: config.chat_password,
      limiter: RateLimiter(String).new)

    client.connect

    active_users_cache = ActivityCache.new(10.minutes)

    prefix = config.prefix
    client.start do |bot|
      Plugins::Ping.bind(bot, prefix)
      Plugins::Channels.bind(bot, prefix, twitch)
      Plugins::Balance.bind(bot, config)
      Plugins::Tip.bind(bot, config, twitch)
      Plugins::Withdraw.bind(bot, config, coin)
      Plugins::Deposit.bind(bot, config, coin)
      Plugins::Support.bind(bot, config)
      Plugins::Donation.bind(bot, config)
      Plugins::Whisper.bind(bot)
      Plugins::Rain.bind(bot, config, twitch, active_users_cache)

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
        Data::TwitchChannel.read_names.each do |channel|
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
  end

  extend self

  # receive wallet transactions and insert into coin_transactions
  def start_listening(config : Config, coin : CoinApi)
    spawn do
      server = HTTP::Server.new do |context|
        next unless context.request.method == "POST"
        txhash = context.request.query_params["tx"]

        tx = coin.get_transaction(txhash).as_h
        next unless tx.is_a?(Hash(String, JSON::Any))
        details_array = tx["details"].as_a
        next unless details_array.is_a?(Array(JSON::Any))

        details_array.each do |details|
          details = details.as_h
          next unless details.is_a?(Hash(String, JSON::Any))

          if details["category"] == "receive"
            # db.create_coin_transaction(txhash)
            # TODO
          end
        end
      end
      server.bind_tcp(config.walletnotify_port)
      server.listen
    end
  end

  # Check for pending deposits and processes them
  def check_pending_deposits(coin : CoinApi, config : Config, twitch : Twitch::Client)
    # txlist = db.db.query_all("SELECT txhash FROM coin_transactions WHERE status = $1", "new", as: String)
    # return if txlist.empty?

    # txlist.each do |transaction|
    #   tx = coin.get_transaction(transaction).as_h
    #   next unless tx.is_a?(Hash(String, JSON::Any))

    #   confirmations = tx["confirmations"].as_i
    #   next unless confirmations >= config.confirmations

    #   details_array = tx["details"].as_a
    #   next unless details_array.is_a?(Array(JSON::Any))

    #   details_array.each do |details|
    #     details = details.as_h
    #     next unless details.is_a?(Hash(String, JSON::Any))

    #     next unless details["category"] == "receive"

    #     # TODO the line below could use some improvement
    #     query = db.db.query_all("SELECT id FROM accounts WHERE address = $1", details["address"], as: Int32)

    #     next if db.update_coin_transaction_status(transaction, "never") if (query == [0] || query.empty?)

    #     user = query[0]
    #     amount = BigDecimal.new(details["amount"].to_s)

    #     db.create_detailed_transaction("deposit", 0, user, amount, transaction)
    #     db.update_balance(user)
    #     db.update_coin_transaction_status(transaction, "credited")
    #     login = twitch.get_user_by_id(db.get_account_twitch_id_by_id(user))
    #     # bot.whisper(login, "Your deposit of #{amount} #{config.short} just got confirmed.")
    #   end
    # end
  end

  # TODO https://github.com/greenbigfrog/discordtipbot/blob/master/src/discordtipbot/tipbot.cr#L69
  def process_pending_withdrawals(coin : CoinApi)
    # TODO
    # db.get_pending_withdrawals.each do |x|
    #   db.db.transaction do |trans|
    #     begin
    #       withdrawal = coin.withdraw(x[:address], x[:amount], "Withdrawal for #{db.get_account_twitch_id_by_id(x[:from_id])}")
    #       db.update_withdrawal_status(x[:id], "processed", trans.connection)
    #     rescue
    #       trans.rollback
    #     end
    #   end
    # end
  end

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

  # Takes a String and parses a BigDecimal Amount
  def amount(balance : BigDecimal, string : String) : BigDecimal?
    if string == "all"
      balance
    elsif string == "half"
      BigDecimal.new(balance / 2).round(8)
    elsif string == "rand"
      BigDecimal.new(Random.rand(1..6))
    elsif string == "bigrand"
      BigDecimal.new(Random.rand(1..42))
    elsif m = /(?<amount>^[0-9,\.]+)/.match(string)
      begin
        return nil unless string == m["amount"]
        BigDecimal.new(m["amount"]).round(8)
      rescue InvalidBigDecimalException
      end
    end
  end

  def mention(login : String, string : String)
    "@#{login} #{string}"
  end
end

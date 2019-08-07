module ChatBot::Plugins::Deposit
  extend self

  def bind(bot, coin)
    bot.on(PRIVWHISP, message: /^#{coin.prefix}deposit/, doc: {"deposit", "Tells the user their address to deposit coins to the bot to"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)

      raise NO_USER_ID unless id = msg.user_id

      # address = Data::DepositAddress.read_or_create(@coin, Data::Account.read(:twitch, id))
      # if address.is_a?(Data::Error)
      #   return client.create_message(msg.channel_id, "Something went wrong. Please try again later, or request help at #{SUPPORT}")
      # end

      # string = "Your deposit address is #{address}"
      string = "Please visit https://tipbot.info/deposit to retrieve your deposit address"
      bot.reply(msg, ChatBot.mention(name, string))
    end
  end
end

module ChatBot::Plugins::Deposit
  extend self

  def bind(bot, coin)
    bot.on(PRIVWHISP, message: /^#{coin.prefix}deposit/, doc: {"deposit", "Tells the user their address to deposit coins to the bot to"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)

      string = "Please visit https://tipbot.info/deposit to retrieve your deposit address"
      bot.reply(msg, ChatBot.mention(name, string))
    end
  end
end

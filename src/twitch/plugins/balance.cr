module ChatBot::Plugins::Balance
  extend self

  def bind(bot, config)
    bot.on(PRIVWHISP, message: /^#{config.prefix}(balance|bal)/, doc: {"balance", "Respond with the users balance"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)
      raise NO_USER_ID unless id = msg.user_id
      # TODO get rid of static coin
      bal = Data::Account.read(:twitch, id).balance(:doge)

      bot.reply(msg, "#{name}'s balance is: #{bal} #{config.short}")
    end
  end
end

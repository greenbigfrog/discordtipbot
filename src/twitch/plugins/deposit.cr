module ChatBot::Plugins::Deposit
  extend self

  def bind(bot, config, coin)
    bot.on(PRIVWHISP, message: /^#{config.prefix}deposit/, doc: {"deposit", "Tells the user their address to deposit coins to the bot to"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)

      raise NO_USER_ID unless id = msg.user_id
      # TODO
      # address = db.get_address_by_twitch_id(id)
      # if address == "" || address.nil?
      #   address = coin.new_address.to_s
      #   db.update_address_by_twitch_id(id, address)
      # end
      address = "nil"

      string = "Your deposit address is #{address}"
      bot.reply(msg, ChatBot.mention(name, string))
    end
  end
end

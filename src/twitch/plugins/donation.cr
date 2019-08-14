module ChatBot::Plugins::Donation
  include TB::Amount
  extend self

  def bind(bot, coin)
    bot.on(PRIVWHISP, message: /^#{coin.prefix}donate/, doc: {"donate", "Donate coins to the owner of the bot to pay for hosting and other expenses"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)

      cmd_usage = "#{coin.prefix}donate [amount]"

      # cmd[0]: trigger, cmd[1]: amount
      cmd = msg.message.try &.split(" ")
      next bot.reply(msg, ChatBot.mention(name, "Please try again! #{cmd_usage}")) unless cmd && cmd.size > 1

      raise NO_USER_ID unless id = msg.user_id

      amount = parse_amount(coin, :twitch, id, cmd[2])
      next bot.reply(msg, ChatBot.mention(name, "Please specify a valid amount")) unless amount
      next bot.reply(msg, ChatBot.mention(name, "You have to tip at least #{coin.default_min_tip} #{coin.name_short}")) unless amount >= coin.default_min_tip

      # TODO get rid of static coin
      res = TB::Data::Account.transfer(amount, coin, id, 102038420, :twitch, :donation)

      if res.is_a?(TB::Data::Error)
        next bot.reply(msg, ChatBot.mention(name, "Insufficient Balance")) if res.reason == "insufficient balance"
        next bot.reply(msg, ChatBot.mention(name, "There was an unexpected error. Please try again later"))
      else
        bot.reply(msg, ChatBot.mention(name, "donated #{amount} #{coin.name_short}!"))
      end
    end
  end
end

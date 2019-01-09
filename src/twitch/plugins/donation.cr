module ChatBot::Plugins::Donation
  include Amount
  extend self

  def bind(bot, config)
    bot.on(PRIVWHISP, message: /^#{config.prefix}donate/, doc: {"donate", "Donate coins to the owner of the bot to pay for hosting and other expenses"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)

      cmd_usage = "#{config.prefix}donate [amount]"

      # cmd[0]: trigger, cmd[1]: amount
      cmd = msg.message.try &.split(" ")
      next bot.reply(msg, ChatBot.mention(name, "Please try again! #{cmd_usage}")) unless cmd && cmd.size > 1

      raise NO_USER_ID unless id = msg.user_id

      amount = parse_amount(:twitch, id, cmd[2])
      next bot.reply(msg, ChatBot.mention(name, "Please specify a valid amount")) unless amount
      next bot.reply(msg, ChatBot.mention(name, "You have to tip at least #{config.min_tip} #{config.short}")) unless amount >= config.min_tip

      # TODO get rid of static coin
      res = Data::Account.transfer(amount, :doge, id, 102038420, :twitch, :donation)

      if res.is_a?(Data::TransferError)
        next bot.reply(msg, ChatBot.mention(name, "Insufficient Balance")) if res.reason == "insufficient balance"
        next bot.reply(msg, ChatBot.mention(name, "There was an unexpected error. Please try again later"))
      else
        bot.reply(msg, ChatBot.mention(name, "donated #{amount} #{config.coinname_short}!"))
      end
    end
  end
end

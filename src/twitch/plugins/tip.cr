module ChatBot::Plugins::Tip
  extend self
  include Amount

  def bind(bot, config, twitch)
    bot.on(PRIVWHISP, message: /^#{config.prefix}tip/, doc: {"tip", "tip [user] [amount]. Allows to tip/transfer cryptocurrency to a other user."}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)
      raise NO_USER_ID unless from = msg.user_id

      cmd_usage = "#{config.prefix}tip [user] [amount]"

      # cmd[0]: trigger, cmd[1]: destination, cmd[2]: amount
      cmd = msg.message.try &.split(" ")
      next bot.reply(msg, ChatBot.mention(name, "Please try again! #{cmd_usage}")) unless cmd && cmd.size > 2

      destination = cmd[1].lstrip('@')
      next bot.reply(msg, ChatBot.mention(name, "Nice try, but you have to specify an actual user.")) unless target = twitch.user(destination)
      target_id = target.id.to_i64

      next bot.reply(msg, ChatBot.mention(name, "You can't tip yourself")) if from == target_id

      amount = parse_amount(:twitch, from, cmd[2])
      next bot.reply(msg, ChatBot.mention(name, "Please specify a valid amount")) unless amount
      next bot.reply(msg, ChatBot.mention(name, "You have to tip at least #{config.min_tip} #{config.short}")) unless amount >= config.min_tip

      # TODO get rid of static coin
      res = Data::Account.transfer(amount, :doge, from, target_id, :twitch, :tip)

      if res.is_a?(Data::TransferError)
        next bot.reply(msg, ChatBot.mention(name, "Insufficient Balance")) if res.reason == "insufficient balance"
        next bot.reply(msg, ChatBot.mention(name, "There was an unexpected error. Please try again later"))
      else
        bot.reply(msg, ChatBot.mention(name, "tipped @#{target.display_name || target.login} #{amount} #{config.short}"))
        # TODO whisper target user, if they haven't received a tip ever before, or the command was issues in a whisper
      end
    end
  end
end

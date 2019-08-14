module ChatBot::Plugins::Withdraw
  extend self
  include TB::Amount

  def bind(bot, coin)
    bot.on(PRIVWHISP, message: /^#{coin.prefix}withdraw/, doc: {"withdraw", "withdraw [address] [amount]. Remove coins from the bot to your own wallet"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)
      raise NO_USER_ID unless id = msg.user_id

      cmd_usage = "#{coin.prefix}withdraw [addess] [amount]"

      # cmd[0]: trigger, cmd[1]: address, cmd[2]: amount
      cmd = msg.message.try &.split(" ")
      next bot.reply(msg, ChatBot.mention(name, "Please try again! #{cmd_usage}")) unless cmd && cmd.size > 2

      address = cmd[1]

      amount = parse_amount(coin, :twitch, id, cmd[2])

      next bot.reply(msg, ChatBot.mention(name, "Please specify a valid amount")) unless amount
      # next bot.reply(msg, ChatBot.mention(name, "You have to withdraw at least #{config.min_withdraw} #{coin.name_short}")) unless amount >= coin.default_min_tip

      account = TB::Data::Account.read(:twitch, id)

      TB::Worker::WithdrawalJob.new(platform: "twitch", destination: msg.arguments.to_s, coin: coin.id, user: account.id, address: address, amount: amount).enqueue
    end
  end
end

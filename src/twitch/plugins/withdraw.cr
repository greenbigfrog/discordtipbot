module ChatBot::Plugins::Withdraw
  extend self

  def bind(bot, config, coin)
    bot.on(PRIVWHISP, message: /^#{config.prefix}withdraw/, doc: {"withdraw", "withdraw [address] [amount]. Remove coins from the bot to your own wallet"}) do |msg|
      name = msg.display_name || ChatBot.extract_nick(msg.source)
      raise NO_USER_ID unless id = msg.user_id

      cmd_usage = "#{config.prefix}withdraw [addess] [amount]"

      # cmd[0]: trigger, cmd[1]: address, cmd[2]: amount
      cmd = msg.message.try &.split(" ")
      next bot.reply(msg, ChatBot.mention(name, "Please try again! #{cmd_usage}")) unless cmd && cmd.size > 2

      address = cmd[1]
      next bot.reply(msg, ChatBot.mention(name, "Please specify a valid address! #{cmd_usage}")) unless coin.validate_address(address)
      next bot.reply(msg, ChatBot.mention(name, "Currently you can't withdraw to internal addresses. Just tip the other user")) if coin.internal?(address)

      # balance = db.get_account_balance_by_twitch_id(id)

      # amount = ChatBot.amount(balance, cmd[2])
      # next bot.reply(msg, ChatBot.mention(name, "Please specify a valid amount")) unless amount
      # next bot.reply(msg, ChatBot.mention(name, "You have to withdraw at least #{config.min_withdraw} #{config.short}")) unless amount >= config.min_tip
      # next bot.reply(msg, ChatBot.mention(name, "Insufficient Balance")) if amount > balance

      # TODO
      # db.db.transaction do |tx|
      #   begin
      #     db.create_transaction("withdrawal", id, 0, amount, tx.connection)
      #     db.create_withdrawal(id, amount, address, tx.connection)
      #     db.update_balance(id, tx.connection)
      #   rescue PQ::PQError
      #     tx.rollback
      #     next bot.reply(msg, ChatBot.mention(name, "There was an unexpected error! #{SUPPORT}"))
      #   end

      #   bot.reply(msg, ChatBot.mention(name, "Your withdrawal will be processed soon"))
      # end
    end
  end
end

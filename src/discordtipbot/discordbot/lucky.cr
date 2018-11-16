class DiscordBot
  def lucky(msg : Discord::Message, cmd_string : String)
    return if private?(msg)
    cmd_usage = "#{@config.prefix}lucky [amount]"

    # cmd[0]: command, cmd[1]: amount"
    cmd = cmd_string.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to lucky rain at least #{@config.min_tip} #{@config.coinname_short}") unless amount >= @config.min_tip

    users = active_users(msg)

    return reply(msg, "**ERROR**: There is no one to make lucky!") unless users && (users = users.to_a).size > 0

    user = users.sample

    case @tip.transfer(from: msg.author.id.to_u64, to: user, amount: amount, memo: "lucky")
    when true
      reply(msg, "#{msg.author.username} luckily rained **#{amount} #{@config.coinname_short}** onto **<@#{user}>**")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when "error"
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    end
  end
end

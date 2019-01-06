class DiscordBot
  include Amount

  def lucky(msg, ctx)
    cmd_usage = "#{@config.prefix}lucky [amount]"

    # cmd[0]: amount
    cmd = ctx[Command].command

    return reply(msg, "Invalid command usage: #{cmd_usage}") if cmd.empty?

    amount = parse_amount(msg, cmd[0])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    min_tip = ctx[ConfigMiddleware].get_decimal_config(msg, "min_tip")
    return reply(msg, "**ERROR**: You have to lucky rain at least #{min_tip} #{@config.coinname_short}") if amount < min_tip

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

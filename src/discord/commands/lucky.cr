class DiscordBot
  include Amount

  def lucky(msg, ctx)
    client = ctx[Discord::Client]

    cmd_usage = "#{@config.prefix}lucky [amount]"

    # cmd[0]: amount
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Invalid command usage: #{cmd_usage}") if cmd.empty?

    amount = parse_amount(msg, cmd[0])
    return client.create_message(msg.channel_id, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    min_tip = ctx[ConfigMiddleware].get_decimal_config(msg, "min_tip")
    return client.create_message(msg.channel_id, "**ERROR**: You have to lucky rain at least #{min_tip} #{@config.coinname_short}") if amount < min_tip

    users = active_users(msg)

    return client.create_message(msg.channel_id, "**ERROR**: There is no one to make lucky!") unless users && (users = users.to_a).size > 0

    user = users.sample

    # TODO get rid of static coin
    res = Data::Account.transfer(amount: amount, coin: :doge, from: msg.author.id.to_u64.to_i64, to: user.to_i64, platform: :discord, memo: :lucky)
    if res.is_a?(Data::TransferError)
      return client.create_message(msg.channel_id, "**ERROR**: Insufficient Balance") if res.reason == "insufficient balance"
      client.create_message(msg.channel_id, "**ERROR**: There was a problem trying to transfer funds#{res.reason ? " (#{res.reason})" : nil}. Please try again later. If the problem persists, please visit the support server at #{SUPPORT}")
    else
      client.create_message(msg.channel_id, "#{msg.author.username} luckily rained **#{amount} #{@config.coinname_short}** onto **<@#{user}>**")
    end
  end
end

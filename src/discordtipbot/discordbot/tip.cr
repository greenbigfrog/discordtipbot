class DiscordBot
  # transfer from user to user
  def tip(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: Who are you planning on tipping? yourself?") if private_channel?(msg)

    cmd_usage = "`#{@config.prefix}tip [@user] [amount]`"
    # cmd[0]: trigger, cmd[1]: user, cmd[2]: amount
    cmd = cmd_string.split(" ")

    return reply(msg, "**ERROR**: Usage: #{cmd_usage}") unless cmd.size > 2

    match = USER_REGEX.match(cmd[1])
    id = match["id"].try &.to_u64 if match

    err = "**ERROR**: Please specify the user you want to tip! #{cmd_usage}"
    return reply(msg, err) unless id
    begin
      to = @cache.resolve_user(id)
    rescue
      return reply(msg, err)
    end

    return reply(msg, "**ERROR**: As a design choice you aren't allowed to tip Bot accounts") if bot?(to)

    return reply(msg, "**ERROR**: Are you trying to tip yourself!?") if id == msg.author.id.to_u64

    return reply(msg, "**ERROR**: The user you are trying to tip isn't able to receive tips") if @config.ignored_users.includes?(id)

    amount = amount(msg, cmd[2])
    return reply(msg, "**ERROR**: Please specify a valid amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to tip at least #{@config.min_tip} #{@config.coinname_short}") if amount < @config.min_tip

    case @tip.transfer(from: msg.author.id.to_u64, to: id, amount: amount, memo: "tip")
    when true
      reply(msg, "#{msg.author.username} tipped **#{amount} #{@config.coinname_short}** to **#{to.username}**")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when "error"
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    end
  end
end

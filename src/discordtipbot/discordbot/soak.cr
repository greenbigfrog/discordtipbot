class DiscordBot
  # send coins to all currently online users
  def soak(msg : Discord::Message, cmd_string : String)
    return reply(msg, "**ERROR**: Who are you planning on making wet? yourself?") if private_channel?(msg)

    return reply(msg, "The owner of this server has disabled #{@config.prefix}soak. You can contact them and ask them to enable it as they should have received a DM with instructions") unless @tip.get_config(guild_id(msg), "soak")

    cmd_usage = "#{@config.prefix}soak [amount]"

    # cmd[0]: command, cmd[1]: amount
    cmd = cmd_string.split(" ")

    return reply(msg, cmd_usage) unless cmd.size > 1

    amount = amount(msg, cmd[1])
    return reply(msg, "**ERROR**: You have to specify an amount! #{cmd_usage}") unless amount

    return reply(msg, "**ERROR**: You have to soak at least **#{@config.min_soak_total} #{@config.coinname_short}**") unless amount >= @config.min_soak_total

    return reply(msg, "**ERROR**: Something went wrong") unless guild_id = guild_id(msg)

    trigger_typing(msg)

    users = Array(UInt64).new
    last_id = 0_u64

    loop do
      new_users = @bot.list_guild_members(guild_id, after: last_id)
      break if new_users.size == 0
      last_id = new_users.last.user.id
      new_users.reject!(&.user.bot)
      new_users.each do |x|
        next unless @presence_cache.online?(x.user.id.to_u64)
        users << x.user.id.to_u64 unless x.user.id.to_u64 == msg.author.id.to_u64
        @cache.cache(x.user)
      end
    end

    # TODO only soak people that can view the channel

    users = users - @config.ignored_users.to_a

    return reply(msg, "No one wants to get wet right now :sob:") unless users.size > 1

    if (users.size * @config.min_soak) > @config.min_soak_total
      targets = users.sample((amount / @config.min_soak).to_i32)
    else
      targets = users
    end
    targets.reject! { |x| x == nil }

    case @tip.multi_transfer(from: msg.author.id.to_u64, users: targets, total: amount, memo: "soak")
    when "insufficient balance"
      reply(msg, "**ERROR**: Insufficient balance")
    when false
      reply(msg, "**ERROR**: There was a problem trying to transfer funds. Please try again later. If the problem persists, please contact the dev for help in #{@config.prefix}support")
    when true
      amount_each = BigDecimal.new(amount / targets.size).round(8)

      string = build_user_string(get_config_mention(msg), targets)

      reply(msg, "**#{msg.author.username}** soaked a total of **#{amount_each * targets.size} #{@config.coinname_short}** (#{amount_each} #{@config.coinname_short} each) onto #{string}")
    end
  end
end

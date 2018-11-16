class DiscordBot
  def admin(msg : Discord::Message, cmd_string : String)
    return if admin_alarm?(msg)
    return reply(msg, "**ERROR**: This command only works in DMs") unless private_channel?(msg)

    # cmd[0] = command, cmd[1] = type, cmd [2] = user
    cmd = cmd_string.split(" ")

    return reply(msg, "Current total user balances: **#{@tip.db_balance}**") if cmd.size == 1

    case cmd[1]?
    when "unclaimed"
      node = @tip.node_balance
      return if node.nil?
      unclaimed = node - (@tip.deposit_sum - @tip.withdrawal_sum)

      return reply(msg, "Unclaimed coins: **#{unclaimed}** #{@config.coinname_short}")
    when "balance"
      return reply(msg, "**ERROR**: You forgot to supply an ID to check balance of") unless cmd[2]?
      bal = @tip.get_balance(cmd[2].to_u64)
      reply(msg, "**#{cmd[2]}**'s balance is: **#{bal}** #{@config.coinname_short}")
    end
  end

  def admin_config(msg : Discord::Message, cmd_string : String)
    return if admin_alarm?(msg)

    # Currently the same coins have to be present in both the old and new config file

    # cmd[0] = command, cmd [1] = path
    cmd = cmd_string.split(" ")

    path = cmd[1]? || ARGV[0]

    begin
      Config.reload(path)
    rescue ex
      return reply(msg, "There was an issue loading config from `#{path}`\n```cr\n#{ex.inspect_with_backtrace}```")
    end
    @config = Config.current[@config.coinname_short]
    reply(msg, "Loaded config from #{path}")
  end
end

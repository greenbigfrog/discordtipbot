class ConfigCommand
  include DiscordMiddleware::CachedRoutes

  def initialize(@tip : TipBot)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    # cmd[0] = memo, cmd[1] = status
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Usage: `config [memo] [on/off/amount]") unless cmd.size == 2

    memo = cmd[0]
    return client.create_message(msg.channel_id, "Settings available: #{CONFIG_COLLUMNS}}") unless CONFIG_COLLUMNS.includes?(memo)
    if PREMIUM_CONFIG.includes?(memo)
      unless ctx[ConfigMiddleware].get_config(msg, "premium")
        return client.create_message(msg.channel_id, "This is a premium only config command. Visit <https://tipbot.gbf.re> for more info")
      end
    end

    case cmd[1]
    when "on"
      status = true
    when "off"
      status = false
    else
      begin
        status = BigDecimal.new(cmd[1])
      rescue InvalidBigDecimalException
        return client.create_message(msg.channel_id, "You can set [on/off/amount]")
      end
    end

    return unless guild_id = get_channel(client, msg.channel_id).guild_id

    return client.create_message(msg.channel_id, "Successfully set #{memo} #{cmd[1]}") if @tip.update_config(memo, status, guild_id.to_u64)
    client.create_message(msg.channel_id, "Illegal Operation. Unable to set #{memo} #{cmd[1]}")
    yield
  end
end

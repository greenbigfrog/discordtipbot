class ConfigCommand
  def initialize(@tip : TipBot)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!

    # cmd[0] = memo, cmd[1] = status
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Usage: `config [memo] [on/off/amount]") unless cmd.size == 2

    memo = cmd[0]
    client.create_message(msg.channel_id, "Settings available: #{CONFIG_COLLUMNS}}") unless CONFIG_COLLUMNS.includes?(memo)

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

    guild_id = cache.resolve_channel(msg.channel_id).guild_id.try &.to_u64
    return if guild_id.nil?

    return client.create_message(msg.channel_id, "Successfully set #{memo} #{cmd[1]}") if @tip.update_config(memo, status, guild_id)
    client.create_message(msg.channel_id, "Illegal Operation. Unable to set #{memo} #{cmd[1]}")
    yield
  end
end

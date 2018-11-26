class Prefix
  def initialize(@tip : TipBot)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!

    # cmd[0] = new_prefix
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Usage: `.prefix [new_prefix]") if cmd.empty?

    guild_id = cache.resolve_channel(msg.channel_id).guild_id.try &.to_u64
    return if guild_id.nil?

    return client.create_message(msg.channel_id, "Successfully set the prefix to `#{cmd[0]}`") if @tip.update_config("prefix", cmd[0], guild_id)
    client.create_message(msg.channel_id, "An error occured. Please try again or get support at <http://tipbot.gbf.re>")
    yield
  end
end

class Prefix
  def initialize(@tip : TipBot)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!

    # cmd[0] = new_prefix
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Usage: `.prefix \"[new_prefix/clear]\"`\nCurrent prefix is `#{ctx[ConfigMiddleware].get_prefix(msg)}`") if cmd.empty?

    guild_id = cache.resolve_channel(msg.channel_id).guild_id.try &.to_u64
    return if guild_id.nil?

    string = cmd.join(' ').strip('"')

    if string.starts_with?("clear")
      return client.create_message(msg.channel_id, "Successfully cleared prefix. Only prefix is mentioning now") if @tip.clear_config("prefix", guild_id)
    end

    return client.create_message(msg.channel_id, "Successfully set the prefix to **`#{string + ZWS}`**") if @tip.update_config("prefix", string, guild_id)
    client.create_message(msg.channel_id, "**ERROR:** Please try again or get support at <http://tipbot.gbf.re>")
    yield
  end
end

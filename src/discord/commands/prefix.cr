class Prefix
  include DiscordMiddleware::CachedRoutes

  def initialize(@coin : TB::Data::Coin)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]

    # cmd[0] = new_prefix
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Usage: `.prefix \"[new_prefix/clear]\"`\nCurrent prefix is `#{ctx[ConfigMiddleware].get_prefix(msg)}`") if cmd.empty?

    return unless guild_id = get_channel(client, msg.channel_id).guild_id
    guild_id = guild_id.to_u64.to_i64

    string = cmd.join(' ').strip('"')

    if string.starts_with?("clear")
      return client.create_message(msg.channel_id, "Successfully cleared prefix. Only prefix is mentioning now") if TB::Data::Discord::Guild.update_prefix(guild_id, @coin, nil)
    end

    return client.create_message(msg.channel_id, "Successfully set the prefix to **`#{string + ZWS}`**") if TB::Data::Discord::Guild.update_prefix(guild_id, @coin, string)
    client.create_message(msg.channel_id, "**ERROR:** Please try again or get support at <http://tipbot.gbf.re>")
    yield
  end
end

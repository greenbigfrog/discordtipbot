class Vote
  include DiscordMiddleware::CachedRoutes

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!
    bot = cache.resolve_current_user
    cfg = ctx[ConfigMiddleware]
    channel = get_channel(client, msg.channel_id)
    thumbnail = "https://images.discordapp.net/avatars/#{bot.id}/#{bot.avatar}.png"

    embed = Discord::Embed.new
    embed.colour = 0x3c4aa
    embed.description = "Vote on a discord bot list and be rewarded with Free Premium. Learn more by clicking on the links below. You can vote every 12 h.\n\n**Premium Status:**"

    embed.thumbnail = Discord::EmbedThumbnail.new(url: thumbnail)

    url = "https://discordbots.org/bot/#{bot.id}/vote"
    prem = cfg.get_premium_string(Premium::Kind::User, msg.author.id.to_u64)
    embed.fields = [Discord::EmbedField.new(name: "User", value: "#{prem ? prem : "None"}\n[Vote and extend by 1h](#{url})", inline: true)]
    unless channel.type == Discord::ChannelType::DM
      id = channel.guild_id.not_nil!
      prem = cfg.get_premium_string(Premium::Kind::Guild, id.to_u64)
      embed.fields.not_nil!.unshift(Discord::EmbedField.new(name: "Server", value: "#{prem ? prem : "None"}\n[Vote and extend by 15m](#{url}?server=#{id})", inline: true))
    end

    client.create_message(msg.channel_id, ZWS, embed)
    yield
  end
end

class Vote
  include DiscordMiddleware::CachedRoutes

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cache = client.cache.not_nil!
    bot = cache.resolve_current_user

    thumbnail = "https://images.discordapp.net/avatars/#{bot.id}/#{bot.avatar}.png"

    embed = Discord::Embed.new
    embed.colour = 0x3c4aa
    embed.description = "Vote on a discord bot list and be rewarded with Free Premium. Learn more by clicking on the links below. You can vote every 12 h.\n\n**Premium Status:**"

    embed.thumbnail = Discord::EmbedThumbnail.new(url: thumbnail)

    url = "https://discordbots.org/bot/#{bot.id}/vote"

    embed.fields = [Discord::EmbedField.new(name: "Test", value: "[Vote](#{url})", inline: true)]

    client.create_message(msg.channel_id, ZWS, embed)
    yield
  end
end

class CheckConfig
  include DiscordMiddleware::CachedRoutes

  def call(msg, ctx)
    client = ctx[Discord::Client]
    channel = get_channel(client, msg.channel_id)
    dm = channel.type.dm?

    fields = Array(Discord::EmbedField).new(8)
    fields << Discord::EmbedField.new("Soak", string(ctx[ConfigMiddleware].get_config(msg, "soak")), true) unless dm
    fields << Discord::EmbedField.new("Min Soak", ctx[ConfigMiddleware].get_decimal_config(msg, "min_soak").to_s, true)
    fields << Discord::EmbedField.new("Min Soak Total", ctx[ConfigMiddleware].get_decimal_config(msg, "min_soak_total").to_s, true)
    fields << Discord::EmbedField.new("Rain", string(ctx[ConfigMiddleware].get_config(msg, "rain")), true) unless dm
    fields << Discord::EmbedField.new("Min Rain", ctx[ConfigMiddleware].get_decimal_config(msg, "min_rain").to_s, true)
    fields << Discord::EmbedField.new("Min Rain Total", ctx[ConfigMiddleware].get_decimal_config(msg, "min_rain_total").to_s, true)
    fields << Discord::EmbedField.new("Mention", string(ctx[ConfigMiddleware].get_config(msg, "mention")), true) unless dm
    fields << Discord::EmbedField.new("Min Tip", ctx[ConfigMiddleware].get_decimal_config(msg, "min_tip").to_s, true)

    client.create_message(msg.channel_id,
      ZWS,
      Discord::Embed.new(
        description: "This commands represents the config of the current server. Edit it with `config`",
        fields: fields))
    yield
  end

  private def string(input)
    input ? "on" : "off"
  end
end

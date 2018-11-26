class CheckConfig
  def call(msg, ctx)
    fields = [
      Discord::EmbedField.new("Min Soak", ctx[ConfigMiddleware].get_decimal_config(msg, "min_soak").to_s, true),
      Discord::EmbedField.new("Min Soak Total", ctx[ConfigMiddleware].get_decimal_config(msg, "min_soak_total").to_s, true),
      Discord::EmbedField.new("Min Rain", ctx[ConfigMiddleware].get_decimal_config(msg, "min_rain").to_s, true),
      Discord::EmbedField.new("Min Rain Total", ctx[ConfigMiddleware].get_decimal_config(msg, "min_rain_total").to_s, true),
      Discord::EmbedField.new("Min Tip", ctx[ConfigMiddleware].get_decimal_config(msg, "min_tip").to_s, true),
    ]
    unless ctx[Discord::Client].cache.try &.resolve_channel(msg.channel_id).type == Discord::ChannelType::DM
      fields.insert(0, Discord::EmbedField.new("Soak", string(ctx[ConfigMiddleware].get_config(msg, "soak")), true))
      fields.insert(3, Discord::EmbedField.new("Rain", string(ctx[ConfigMiddleware].get_config(msg, "rain")), true))
      fields.insert(6, Discord::EmbedField.new("Mention", string(ctx[ConfigMiddleware].get_config(msg, "mention")), true))
    end
    ctx[Discord::Client].create_message(msg.channel_id,
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

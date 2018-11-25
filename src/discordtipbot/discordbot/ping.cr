class Ping
  def call(payload, ctx)
    client = ctx[Discord::Client]
    latency = Discord::EmbedField.new("Latency", "#{(Time.utc_now - payload.timestamp).total_milliseconds} ms")
    processing_time = Discord::EmbedField.new("Processed in", "#{(Time.utc_now - ctx[Command].time).total_milliseconds} ms")
    m = client.create_message(payload.channel_id, "Pong!", Discord::Embed.new(fields: [latency, processing_time]))
    return unless m.is_a?(Discord::Message)
    roundtrip = Discord::EmbedField.new("Roundtrip", "#{(Time.utc_now - payload.timestamp).total_milliseconds} ms")
    footer = Discord::EmbedFooter.new("Processing of the whole command took #{(Time.utc_now - ctx[Command].time).total_milliseconds} ms")
    client.edit_message(m.channel_id, m.id,
      "Pong!",
      Discord::Embed.new(footer: footer,
        fields: [latency, processing_time, roundtrip]))
    yield
  end
end

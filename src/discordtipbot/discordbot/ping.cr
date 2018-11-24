class Ping
  def call(payload, ctx)
    client = ctx[Discord::Client]
    m = client.create_message(payload.channel_id, "Pong!")
    return unless m.is_a?(Discord::Message)
    time = Time.utc_now - payload.timestamp
    client.edit_message(m.channel_id, m.id, "Pong! *Time taken: #{time.total_milliseconds} ms.*")
    yield
  end
end

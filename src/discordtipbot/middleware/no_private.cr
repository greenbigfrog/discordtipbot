class NoPrivate
  def call(payload, ctx)
    if ctx[Discord::Client].cache.try &.resolve_channel(payload.channel_id).type == Discord::ChannelType::DM
      ctx[Discord::Client].create_message(payload.channel_id, "This command does not work in DMs")
    else
      yield
    end
  end
end

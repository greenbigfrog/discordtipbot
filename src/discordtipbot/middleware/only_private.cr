class OnlyPrivate
  def call(payload, ctx)
    if ctx[Discord::Client].cache.try &.resolve_channel(payload.channel_id).type != Discord::ChannelType::DM
      ctx[Discord::Client].create_message(payload.channel_id, "This command only works DMs")
    else
      yield
    end
  end
end

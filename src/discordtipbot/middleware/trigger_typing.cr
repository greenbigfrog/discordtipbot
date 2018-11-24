class TriggerTyping
  def call(msg, ctx)
    ctx[Discord::Client].trigger_typing_indicator(msg.channel_id)
    yield
  end
end

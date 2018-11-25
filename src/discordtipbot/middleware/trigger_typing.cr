class TriggerTyping
  def call(msg, ctx)
    spawn ctx[Discord::Client].trigger_typing_indicator(msg.channel_id)
    yield
  end
end

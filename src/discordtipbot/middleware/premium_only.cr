class PremiumOnly
  def call(msg, ctx)
    if ctx[ConfigMiddleware].get_config(msg, "premium")
      yield
    else
      return ctx[Discord::Client].create_message(msg.channel_id, "This is a premium only feature. For more info please visit <http://tipbot.gbf.re>")
    end
  end
end

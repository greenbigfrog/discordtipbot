class PremiumOnly
  include DiscordMiddleware::CachedRoutes

  def call(msg, ctx)
    if ctx[ConfigMiddleware].get_config(msg, "premium")
      yield
    else
      return ctx[Discord::Client].create_message(msg.channel_id, <<-STRING)
      This is a premium only feature. For more info please visit <http://tipbot.gbf.re>

      *Get Free Premium by voting. Check `#{ctx[ConfigMiddleware].get_prefix(msg)}vote` for more info*
      STRING
    end
  end
end

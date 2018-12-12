class PremiumOnly
  include DiscordMiddleware::CachedRoutes

  def call(msg, ctx)
    if ctx[ConfigMiddleware].get_config(msg, "premium")
      yield
    else
      client = ctx[Discord::Client]
      string = String::Builder.build do |io|
        io.puts "This is a premium only feature. For more info please visit <http://tipbot.gbf.re>"
        io.puts
        io << "*Get **15 Minutes premium by voting** at https://discordbots.org/bot/"
        io << client.cache.not_nil!.resolve_current_user.id
        io << "/vote?server="
        io << get_channel(client, msg.channel_id).guild_id
        io << '*'
      end
      return ctx[Discord::Client].create_message(msg.channel_id, string)
    end
  end
end

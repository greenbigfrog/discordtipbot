class PremiumOnly
  def call(msg, ctx)
    if ctx[ConfigMiddleware].get_config(msg, "premium")
      yield
    else
      cache = ctx[Discord::Client].cache.not_nil!
      string = String::Builder.build do |io|
        io.puts "This is a premium only feature. For more info please visit <http://tipbot.gbf.re>"
        io.puts
        io << "*Get **15 Minutes premium by voting** at https://discordbots.org/bot/"
        io << cache.try &.resolve_current_user.id
        io << "/vote?server="
        io << cache.resolve_channel(msg.channel_id).guild_id
        io << '*'
      end
      return ctx[Discord::Client].create_message(msg.channel_id, string)
    end
  end
end

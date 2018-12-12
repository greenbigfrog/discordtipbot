require "rate_limiter"

class MW::RateLimiter
  include DiscordMiddleware::CachedRoutes

  def initialize
    @limiter = ::RateLimiter(Discord::Snowflake).new
    @limiter.bucket(:intense, 1_u32, 2.minutes)
    @limiter.bucket(:guild, 5_u32, 10.seconds)
    @limiter.bucket(:user, 2_u32, 10.seconds)

    @intense = {"soak", "rain"}
  end

  private def reply(client, channel_id)
    client.create_message(channel_id, "This command has been ratelimited. Please wait before trying again. You can get rid of this by getting premium. Visit #{SUPPORT} for more info.")
  end

  def call(payload, ctx)
    client = ctx[Discord::Client]

    premium = ctx[ConfigMiddleware].get_premium(payload)

    unless premium
      if @limiter.rate_limited?(:user, payload.author.id)
        reply(client, payload.channel_id)
        return
      end

      intense = @intense.includes?(ctx[Command].name)

      if guild_id = get_channel(client, payload.channel_id).guild_id
        if intense
          if @limiter.rate_limited?(:intense, guild_id)
            reply(client, payload.channel_id)
            return
          end
        end
        if @limiter.rate_limited?(:guild, guild_id)
          reply(client, payload.channel_id)
          return
        end
      end
    end

    yield
  end
end

class PremiumCmd
  include DiscordMiddleware::CachedRoutes

  def initialize(@tip : TipBot)
  end

  def call(msg, ctx)
    client = ctx[Discord::Client]
    cmd = ctx[Command].command

    return client.create_message(msg.channel_id, "Invalid Usage. `premium [type] [id] [cmd] [time]?`") unless cmd.size >= 3
    # type, id, cmd, time?
    case cmd[0]
    when "user"            then premium_type = Premium::Kind::User
    when "server", "guild" then premium_type = Premium::Kind::Guild
    else                        return
    end

    begin
      id = cmd[1].to_u64
    rescue
    end

    if cmd[1] == "this" && id.nil?
      channel = get_channel(client, msg.channel_id)
      id = channel.guild_id.not_nil!.to_u64 if premium_type.guild?
      id = msg.author.id.to_u64 unless id
    end
    return unless id

    @tip.clear_expired_premium

    case cmd[2]
    when "status"
    when "extend"
      @tip.extend_premium(premium_type, id, time(cmd[3], cmd[4]))
    end

    human = ctx[ConfigMiddleware].get_premium_string(premium_type, id)
    string = human ? "The guild/user has premium for another **#{human}**" : "The guild/user does **not** have premium"
    client.create_message(msg.channel_id, string)
    yield
  end

  private def time(number : String, span : String) : Time::Span
    case span
    when .starts_with?("minute") then number.to_i.minutes
    when .starts_with?("hour")   then number.to_i.hours
    when .starts_with?("day")    then number.to_i.days
    when .starts_with?("week")   then number.to_i.weeks
    when .starts_with?("month")  then (number.to_i * 30).days
    when .starts_with?("year")   then (number.to_i * 365).days
    else                              0.seconds
    end
  rescue
    0.seconds
  end
end

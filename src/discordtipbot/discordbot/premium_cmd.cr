class PremiumCmd
  def initialize(@tip : TipBot)
  end

  def call(msg, ctx)
    # TODO
    client = ctx[Discord::Client]
    cmd = ctx[Command].command
    cache = client.cache.not_nil!

    begin
      method = cmd[1]? if guild_id = cmd[0]?.try &.to_u64
    rescue
    end
    guild_id = cache.resolve_channel(msg.channel_id).guild_id.try &.to_u64 unless guild_id
    return unless guild_id

    @tip.clear_expired_premium

    case method || cmd[0]?
    when "status"
    when "extend"
      time_array = method ? cmd[2..3] : cmd[1..2]
      @tip.extend_premium(Premium::Kind::Guild, guild_id, time(time_array[0], time_array[1]))
    end

    human = ctx[ConfigMiddleware].get_premium_string(Premium::Kind::Guild, guild_id)
    string = human ? "The guild has premium for another **#{human}**" : "The guild does **not** have premium"
    client.create_message(msg.channel_id, string)
    yield
  end

  private def time(number : String, span : String) : Time::Span
    case span
    when .starts_with?("minute") then number.to_i.minutes
    when .starts_with?("hour")   then number.to_i.hours
    when .starts_with?("day")    then number.to_i.days
    when .starts_with?("month")  then (number.to_i * 30).days
    when .starts_with?("year")   then (number.to_i * 365).days
    else                              0.seconds
    end
  rescue
    0.seconds
  end
end

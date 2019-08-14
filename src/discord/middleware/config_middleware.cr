class ConfigMiddleware
  getter cache : Discord::Cache | Nil

  def initialize(@coin : TB::Data::Coin)
  end

  def call(msg, ctx)
    @cache = ctx[Discord::Client].cache.not_nil!
    yield
  end

  def get_prefix(msg)
    return @coin.prefix if @cache.not_nil!.resolve_channel(msg.channel_id).type == Discord::ChannelType::DM
    TB::Data::Discord::Guild.read_prefix(guild_id(msg), @coin) || @coin.prefix
  end

  def get_config(msg : Discord::Message, memo : String)
    TB::Data::Discord::Guild.read_config(guild_id(msg), @coin, memo) || false
  end

  def get_decimal_config(msg : Discord::Message, memo : String)
    res = TB::Data::Discord::Guild.read_decimal_config(guild_id(msg), @coin, memo)
    # TODO `get` macro
    res || @coin.get("default_#{memo}")
  end

  private def guild_id(msg)
    res = @cache.not_nil!.resolve_channel(msg.channel_id).guild_id
    raise "Somehow we were unable to get a guild_id" unless res
    res.to_u64.to_i64
  end

  # def reduce(num : BigDecimal)
  #   scale = num.scale
  #   value = num.value
  #   if scale > 0
  #     if value % 10
  #       new_scale = get_scale(value, scale)
  #       new_value = value / (10**(scale - new_scale))
  #       return BigDecimal.new(new_value, new_scale)
  #     end
  #   end
  #   num
  # end

  # def get_scale(value, scale)
  #   if value > 10
  #     return scale if scale == 0
  #     get_scale(value / 10, scale - 1)
  #   else
  #     scale
  #   end
  # end
end

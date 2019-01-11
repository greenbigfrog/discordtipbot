class ConfigMiddleware
  getter cache : Discord::Cache | Nil
  @db : DB::Database

  def initialize(@coin : Data::Coin, @tip : TipBot, @config : Config)
    @db = @tip.db
  end

  def call(msg, ctx)
    @cache = ctx[Discord::Client].cache.not_nil!
    yield
  end

  def get_prefix(msg)
    Data::GuildConfig.read_prefix(guild_id(msg), @coin) || @config.prefix
  end

  def get_config(msg : Discord::Message, memo : String)
    Data::GuildConfig.read_config(guild_id(msg), @coin, memo) || false
    # DATA.query_one?("SELECT #{memo} FROM guild_configs WHERE guild = $1 AND coin = $2", server_id(msg), @coin, as: Bool?) || false
  end

  def get_decimal_config(msg : Discord::Message, memo : String)
    res = Data::GuildConfig.read_decimal_config(guild_id(msg), @coin, memo)
    res || @config.get(memo)
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

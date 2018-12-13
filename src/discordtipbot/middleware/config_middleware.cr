class ConfigMiddleware
  getter cache : Discord::Cache | Nil
  @db : DB::Database

  def initialize(@tip : TipBot, @config : Config)
    @db = @tip.db
  end

  def call(msg, ctx)
    @cache = ctx[Discord::Client].cache.not_nil!
    yield
  end

  def get_prefix(msg)
    @db.query_one?("SELECT prefix FROM config WHERE serverid = $1", server_id(msg), as: String?) || @config.prefix
  end

  def get_config(msg : Discord::Message, memo : String)
    @db.query_one?("SELECT #{memo} FROM config WHERE serverid = $1", server_id(msg), as: Bool?) || false
  end

  def get_premium(msg : Discord::Message)
    guild = get_config(msg, "premium")
    return true if guild
    @db.query_one?("SELECT premium FROM accounts WHERE userid = $1", msg.author.id, as: Bool?) || false
  end

  def get_premium_string(kind : Premium::Kind, id)
    status = @tip.status_premium(kind, id)
    HumanizeTime.distance_of_time_in_words(Time.utc_now, status) if status
  end

  def get_decimal_config(msg : Discord::Message, memo : String)
    res = @db.query_one?("SELECT #{memo} FROM config WHERE serverid = $1", server_id(msg),
      as: BigDecimal?)
    res ? reduce(res) : @config.get(memo)
  end

  private def server_id(msg)
    @cache.try &.resolve_channel(msg.channel_id).guild_id
  end

  def reduce(num : BigDecimal)
    scale = num.scale
    value = num.value
    if scale > 0
      if value % 10
        new_scale = get_scale(value, scale)
        new_value = value / (10**(scale - new_scale))
        return BigDecimal.new(new_value, new_scale)
      end
    end
    num
  end

  def get_scale(value, scale)
    if value > 10
      return scale if scale == 0
      get_scale(value / 10, scale - 1)
    else
      scale
    end
  end
end

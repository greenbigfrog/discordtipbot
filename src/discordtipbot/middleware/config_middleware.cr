class ConfigMiddleware
  getter cache : Discord::Cache | Nil

  def initialize(@db : DB::Database, @config : Config)
  end

  def call(msg, ctx)
    @cache = ctx[Discord::Client].cache.not_nil!
    yield
  end

  def get_config(msg : Discord::Message, memo : String)
    server = @cache.try &.resolve_channel(msg.channel_id).guild_id
    @db.query_one("SELECT $1 FROM config WHERE serverid = $2", memo, server, as: Bool?) || false
  end

  def get_decimal_config(msg : Discord::Message, memo : String)
    server = @cache.try &.resolve_channel(msg.channel_id).guild_id
    @db.query_one("SELECT #{memo} FROM config WHERE serverid = $1", server, as: BigDecimal?) || @config.get?(memo)
  end
end

class ConfigMiddleware
  getter cache : Discord::Cache | Nil

  def initialize(@db : DB::Database, @config : Config)
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

  def get_decimal_config(msg : Discord::Message, memo : String)
    @db.query_one?("SELECT #{memo} FROM config WHERE serverid = $1", server_id(msg), as: BigDecimal?) || @config.get?(memo)
  end

  private def server_id(msg)
    @cache.try &.resolve_channel(msg.channel_id).guild_id
  end
end

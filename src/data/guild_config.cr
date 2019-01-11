struct Data::GuildConfig
  DB.mapping(
    guild: Int32,
    coin: Int32,

    prefix: String?,

    mention: Bool,
    soak: Bool,
    rain: Bool,

    min_soak: BigDecimal?,
    min_soak_total: BigDecimal?,

    min_rain: BigDecimal?,
    min_rain_total: BigDecimal?,

    min_tip: BigDecimal?,
    min_lucky: BigDecimal?
  )

  def self.read_prefix(id : Int64, coin : Coin)
    DATA.query_one?("SELECT prefix FROM guild_configs WHERE guild = $1 AND coin = $2", id, coin.id, as: String)
  end

  def self.read_config(id : Int64, coin : Coin, field : String) : Bool?
    DATA.query_one?("SELECT #{field} FROM guild_configs WHERE guild = $1 AND coin = $2", id, coin.id, as: Bool?)
  end

  def self.read_decimal_config(id : Int64, coin : Coin, field : String) : BigDecimal?
    DATA.query_one?("SELECT #{field} FROM guild_configs WHERE guild = $1 AND coin = $2", id, coin.id, as: BigDecimal?)
  end
end
